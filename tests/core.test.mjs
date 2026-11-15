import { describe, expect, test } from "bun:test";
import { createSession, createCatalog, normalizeSettings, retryDeadline } from "../contents/code/providerRouter.mjs";
import * as Formatting from "../contents/code/formatting.mjs";
import * as CoinGecko from "../contents/code/coingecko.mjs";
import * as Catalog from "../contents/code/catalog.mjs";
import { request } from "../contents/code/http.mjs";

function fixture() {
    let now = 1700000000000;
    const timers = [];
    const requests = [];
    let state;
    const env = {
        now: () => now,
        random: () => 0,
        changed: (next) => {
            state = next;
        },
        schedule: (delay, callback) => {
            const timer = { at: now + delay, callback, cancelled: false };
            timers.push(timer);
            return () => {
                timer.cancelled = true;
            };
        },
        request: (spec, timeout, done) => {
            const pending = { spec, timeout, done, cancelled: false };
            requests.push(pending);
            return () => {
                pending.cancelled = true;
            };
        },
    };
    return {
        env,
        requests,
        timers,
        get state() {
            return state;
        },
        respond(index, data, status = 200, retryAfter = "") {
            requests[index].done(null, { status, body: JSON.stringify(data), retryAfter });
        },
        advance(ms) {
            const end = now + ms;
            for (;;) {
                timers.sort((a, b) => a.at - b.at);
                const timer = timers.find((item) => !item.cancelled && item.at <= end);
                if (!timer) break;
                now = timer.at;
                timer.cancelled = true;
                timer.callback();
            }
            now = end;
        },
    };
}

const defaults = normalizeSettings({});
const catalog = [
    { id: "bitcoin", symbol: "btc", name: "Bitcoin" },
    { id: "first", symbol: "dup", name: "First" },
    { id: "second", symbol: "dup", name: "Second" },
];

describe("formatting and identity", () => {
    test("zero settings survive normalization and decimals remain bounded", () => {
        expect(
            Formatting.normalize({ standardPriceDecimals: 0, standardPriceThreshold: 0 }).standardPriceDecimals,
        ).toBe(0);
        expect(Formatting.normalize({ minSmallPriceDecimals: 7, maxSmallPriceDecimals: 2 }).maxSmallPriceDecimals).toBe(
            7,
        );
        expect(Formatting.formatPrice(1.75, { standardPriceDecimals: 0 })).toBe("2");
        expect(Formatting.formatPrice(1234.5, {})).toBe("1235");
        expect(Formatting.formatPrice(0.000012345, {})).toBe("0.0000123");
        expect(Formatting.formatPrice(0, {})).toBe("0");
        expect(Formatting.formatPrice(NaN, {})).toBe("");
        expect(Formatting.formatPrice(-1, {})).toBe("");
        expect(Formatting.formatPrice(1.25, { standardPriceDecimals: 999 })).toBe("1.25");
    });
    test("decimal and grouping localization are independent", () => {
        expect(Formatting.localize("1234.5", ",", (n) => n.toLocaleString("de-DE"))).toBe("1.234,5");
        expect(Formatting.localize("1234.5", ",", String)).toBe("1234,5");
        expect(Formatting.localize("-1234.5", ".", (n) => n.toLocaleString("en-US"))).toBe("-1,234.5");
    });
    test("exact identities win and duplicate symbols are rejected", () => {
        expect(CoinGecko.resolveIdentity("second", "dup", catalog).id).toBe("second");
        expect(CoinGecko.resolveIdentity("btc", "btc", catalog).id).toBe("bitcoin");
        expect(CoinGecko.resolveIdentity("dup", "dup", catalog).error.code).toBe("ambiguous");
        expect(CoinGecko.resolveIdentity("unknown", "unknown", catalog).error.code).toBe("unsupported");
    });
    test("search never mutates catalog or selected identity", () => {
        expect(Catalog.search(catalog, "BT", 2).map((c) => c.id)).toEqual(["bitcoin"]);
        expect(Catalog.search(catalog, "b", 2)).toEqual([]);
        expect(catalog[0].id).toBe("bitcoin");
        const enriched = Catalog.enrichBinance(
            [
                { id: "btc", symbol: "btc", name: "BTC" },
                { id: "dup", symbol: "dup", name: "DUP" },
            ],
            catalog,
        );
        expect(enriched.find((c) => c.symbol === "btc").id).toBe("bitcoin");
        expect(enriched.find((c) => c.symbol === "dup").id).toBe("dup");
    });
    test("Pro endpoint uses a header and never embeds credentials in the URL", () => {
        const spec = CoinGecko.priceRequest({ ...defaults, apiKey: "secret" }, "bitcoin");
        expect(spec.url).toStartWith("https://pro-api.coingecko.com/api/v3/simple/price?");
        expect(spec.url).not.toContain("secret");
        expect(spec.headers["x-cg-pro-api-key"]).toBe("secret");
    });
});

describe("quote lifecycle", () => {
    test("keeps quotes while refreshing and preserves timestamps after failure", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure(defaults);
        f.respond(0, { price: "100" });
        const quote = f.state.quote;
        session.refresh();
        expect(f.state.quote).toBe(quote);
        expect(f.state.loading).toBe(true);
        f.respond(1, {}, 403);
        expect(f.state.quote).toBe(quote);
        expect(f.state.error.code).toBe("access");
        expect(f.state.loading).toBe(false);
    });
    test("clears quotes for changed identities and rejects obsolete callbacks", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure(defaults);
        f.respond(0, { price: "100" });
        session.refresh();
        session.configure({ ...defaults, coin: "ethereum", coinSymbol: "eth" });
        expect(f.requests[1].cancelled).toBe(true);
        expect(f.state.quote).toBe(null);
        f.respond(1, { price: "999" });
        expect(f.state.quote).toBe(null);
        f.respond(2, { price: "10" });
        expect(f.state.quote.price).toBe(10);
    });
    test("provider and base-currency changes invalidate quotes", () => {
        for (const change of [{ apiProvider: "coingecko" }, { baseCurrency: "eur" }]) {
            const f = fixture();
            const session = createSession(f.env);
            session.configure(defaults);
            f.respond(0, { price: "100" });
            session.configure({ ...defaults, ...change });
            expect(f.state.quote).toBe(null);
        }
    });
    test("same settings and polling never duplicate or interrupt active work", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure(defaults);
        session.configure(defaults);
        session.refresh();
        expect(f.requests).toHaveLength(1);
        expect(f.requests[0].cancelled).toBe(false);
    });
    test("unsupported Binance pairs fall back and retain real source timestamps", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure({ ...defaults, baseCurrency: "usd", show24hChange: true });
        f.respond(0, { code: -1121 }, 400);
        expect(f.requests[1].spec.url).toContain("ids=bitcoin");
        f.respond(1, { bitcoin: { usd: 42, usd_24h_change: null, last_updated_at: 1699999900 } });
        expect(f.state.quote).toMatchObject({
            price: 42,
            change24h: null,
            provider: "coingecko",
            fallback: true,
            updatedAt: 1699999900000,
        });
    });
    test("legacy IDs are resolved before fallback, ambiguous symbols stop", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure({ ...defaults, coin: "dup", coinSymbol: "dup" });
        f.respond(0, { code: -1121 }, 400);
        expect(f.requests[1].spec.url).toContain("coins/list");
        f.respond(1, catalog);
        expect(f.state.error.code).toBe("ambiguous");
        expect(f.requests).toHaveLength(2);
    });
    test("invalid numbers never become a quote; missing change is not zero", () => {
        for (const price of [null, "", " ", "NaN", "Infinity", -1, true, [], {}]) {
            const f = fixture();
            const session = createSession(f.env);
            session.configure(defaults);
            f.respond(0, { price });
            expect(f.state.quote).toBe(null);
            expect(f.state.error.code).toBe("invalid-response");
        }
        const f = fixture();
        const session = createSession(f.env);
        session.configure({ ...defaults, show24hChange: true });
        f.respond(0, { lastPrice: "0", priceChangePercent: "0" });
        expect(f.state.quote).toMatchObject({ price: 0, change24h: 0 });
    });
    test("malformed responses end loading", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure(defaults);
        f.requests[0].done(null, { status: 200, body: "<html>", retryAfter: "" });
        expect(f.state.loading).toBe(false);
        expect(f.state.error.code).toBe("invalid-response");
    });
    test("Retry-After longer than a minute survives polling and final failure", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure(defaults);
        for (let attempt = 0; attempt < 3; ++attempt) {
            f.respond(attempt, {}, 429, "120");
            session.refresh();
            f.advance(119999);
            expect(f.requests).toHaveLength(attempt + 1);
            if (attempt < 2) f.advance(1);
        }
        expect(f.state.loading).toBe(false);
        session.refresh();
        expect(f.requests).toHaveLength(3);
        f.advance(1);
        session.refresh();
        expect(f.requests).toHaveLength(4);
    });
    test("date Retry-After and invalid headers", () => {
        const now = Date.UTC(2026, 0, 1);
        expect(retryDeadline(new Date(now + 120000).toUTCString(), now)).toBe(now + 120000);
        expect(retryDeadline("invalid", now)).toBe(0);
    });
    test("configuration changes and manual refresh cannot bypass cooldowns", () => {
        const f = fixture();
        const session = createSession(f.env);
        session.configure(defaults);
        f.respond(0, {}, 429, "120");
        session.configure({ ...defaults, baseCurrency: "eur" });
        session.refresh();
        f.advance(119999);
        expect(f.requests).toHaveLength(1);
        f.advance(1);
        session.refresh();
        expect(f.requests).toHaveLength(2);
        expect(f.requests[1].spec.url).toContain("BTCEUR");
    });
    test("disposal cancels retries and instances are isolated", () => {
        const first = fixture();
        const second = fixture();
        const a = createSession(first.env);
        const b = createSession(second.env);
        a.configure(defaults);
        b.configure(defaults);
        first.respond(0, {}, 500);
        a.dispose();
        first.advance(10000);
        expect(first.requests).toHaveLength(1);
        second.respond(0, { price: "5" });
        expect(second.state.quote.price).toBe(5);
    });
    test("catalog cancellation rejects out-of-order provider results", () => {
        const f = fixture();
        const service = createCatalog(f.env);
        const results = [];
        service.load("binance", "", (error, coins) => results.push({ error, coins }));
        service.load("coingecko", "", (error, coins) => results.push({ error, coins }));
        f.respond(0, { symbols: [{ status: "TRADING", baseAsset: "BTC" }] });
        expect(results).toHaveLength(0);
        f.respond(1, catalog);
        expect(results[0].coins).toEqual(catalog);
        service.dispose();
    });
});

describe("HTTP completion", () => {
    function xhr() {
        return {
            readyState: 0,
            status: 0,
            responseText: "",
            onreadystatechange: null,
            aborted: false,
            open() {},
            send() {},
            setRequestHeader() {},
            getResponseHeader() {
                return null;
            },
            abort() {
                this.aborted = true;
                this.onreadystatechange?.();
            },
        };
    }
    test("deadline aborts once and ignores late completion", () => {
        const f = fixture();
        const fake = xhr();
        const results = [];
        request(
            { url: "https://example.test" },
            5000,
            (error) => results.push(error),
            f.env.schedule,
            () => fake,
        );
        const callback = fake.onreadystatechange;
        f.advance(5000);
        expect(fake.aborted).toBe(true);
        expect(results).toEqual([{ code: "timeout" }]);
        fake.readyState = 4;
        fake.status = 200;
        callback();
        expect(results).toHaveLength(1);
    });
    test("success stops deadline; cancellation emits nothing", () => {
        const f = fixture();
        const fake = xhr();
        const results = [];
        request(
            { url: "https://example.test" },
            5000,
            (error, response) => results.push({ error, response }),
            f.env.schedule,
            () => fake,
        );
        fake.readyState = 4;
        fake.status = 200;
        fake.responseText = "{}";
        fake.onreadystatechange();
        f.advance(5000);
        expect(results).toHaveLength(1);
        expect(fake.aborted).toBe(false);
        const next = xhr();
        const cancel = request(
            { url: "https://example.test" },
            5000,
            (error) => results.push(error),
            f.env.schedule,
            () => next,
        );
        cancel();
        f.advance(5000);
        expect(results).toHaveLength(1);
        expect(next.aborted).toBe(true);
    });
});
