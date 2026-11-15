import * as Binance from "./binance.mjs";
import * as CoinGecko from "./coingecko.mjs";
import { bounded } from "./formatting.mjs";

/** @param {string} header @param {number} now */
export function retryDeadline(header, now) {
    if (!header.trim()) return 0;
    const seconds = Number(header);
    const deadline = Number.isFinite(seconds) ? now + Math.max(0, seconds) * 1000 : Date.parse(header);
    return Number.isFinite(deadline) ? Math.max(now, deadline) : 0;
}

/** One cancellable operation, including retries and all chained requests.
 * @param {import('./contracts').Environment} env
 * @param {(deadline: number) => void} onRetry */
function operation(env, onRetry) {
    let alive = true;
    let cancelPending = () => {};
    /** @param {import('./contracts').RequestSpec} spec @param {number} timeout
     * @param {(error: import('./contracts').Failure | null, data?: unknown) => void} done
     * @param {number} attempt */
    function json(spec, timeout, done, attempt = 0) {
        if (!alive) return;
        let completedSynchronously = false;
        const handle = env.request(spec, timeout, (error, response) => {
            completedSynchronously = true;
            if (!alive) return;
            const status = response?.status ?? 0;
            const transient =
                error?.code === "network" ||
                error?.code === "timeout" ||
                status === 429 ||
                status === 418 ||
                status >= 500;
            if (transient) {
                const serverDeadline = retryDeadline(response?.retryAfter ?? "", env.now());
                const deadline = Math.max(
                    serverDeadline,
                    env.now() + Math.min(8000, 1000 * 2 ** attempt) + Math.floor(env.random() * 250),
                );
                // A final failure also retains the server's cooldown for future refreshes.
                onRetry(deadline);
                if (attempt < 2) {
                    cancelPending = env.schedule(deadline - env.now(), () => json(spec, timeout, done, attempt + 1));
                    return;
                }
                done(
                    error ?? {
                        code: status === 429 || status === 418 ? "rate-limit" : "server",
                        status,
                        retryAt: deadline,
                    },
                );
                return;
            }
            if (error) {
                done(error);
                return;
            }
            /** @type {unknown} */
            let data;
            try {
                data = JSON.parse(response?.body ?? "");
            } catch (_) {
                done({ code: "invalid-response", status });
                return;
            }
            if (status !== 200) {
                const code = data && typeof data === "object" && "code" in data ? data.code : null;
                done({
                    code:
                        status === 400 && code === -1121
                            ? "unsupported-pair"
                            : status === 401 || status === 403
                              ? "access"
                              : "http",
                    status,
                });
                return;
            }
            done(null, data);
        });
        if (!completedSynchronously) cancelPending = handle;
    }
    return {
        json,
        cancel() {
            alive = false;
            cancelPending();
        },
    };
}

/** @param {Partial<import('./contracts').Settings>} settings @returns {import('./contracts').Settings} */
export function normalizeSettings(settings) {
    return {
        coin: String(settings.coin ?? "bitcoin")
            .trim()
            .toLowerCase(),
        coinSymbol: String(settings.coinSymbol ?? "btc")
            .trim()
            .toLowerCase(),
        baseCurrency: String(settings.baseCurrency ?? "usdt")
            .trim()
            .toLowerCase(),
        apiProvider: settings.apiProvider === "coingecko" ? "coingecko" : "binance",
        apiKey: String(settings.apiKey ?? "").trim(),
        timeout: bounded(settings.timeout, 5, 5, 60),
        refreshInterval: bounded(settings.refreshInterval, 60, 5, 1000),
        show24hChange: settings.show24hChange === true,
    };
}
/** @param {import('./contracts').Settings} settings */
export function quoteKey(settings) {
    return JSON.stringify([settings.coin, settings.coinSymbol, settings.baseCurrency, settings.apiProvider]);
}
/** @param {unknown} value */
function numberOrNull(value) {
    if ((typeof value !== "number" && typeof value !== "string") || String(value).trim() === "") return null;
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
}

/** All mutable state is per widget, never shared through an ES module.
 * @param {import('./contracts').Environment} env */
export function createSession(env) {
    let settings = normalizeSettings({});
    /** @type {import('./contracts').State} */
    let state = { quote: null, loading: false, error: null, retryAt: 0 };
    /** @type {ReturnType<typeof operation> | null} */
    let active = null;
    /** @type {import('./contracts').Coin[]} */
    let catalog = [];
    let catalogUntil = 0;
    let disposed = false;
    let generation = 0;
    const publish = () => {
        if (!disposed) env.changed(Object.assign({}, state));
    };
    function refresh() {
        if (disposed || active || env.now() < state.retryAt) return;
        const current = settings;
        const token = ++generation;
        state = Object.assign({}, state, { loading: true, error: null, retryAt: 0 });
        publish();
        const work = operation(env, (deadline) => {
            state.retryAt = deadline;
            publish();
        });
        active = work;
        /** @param {import('./contracts').Failure | null} error @param {import('./contracts').Quote} [quote] */
        const finish = (error, quote) => {
            if (disposed || token !== generation) return;
            active = null;
            state = { quote: quote ?? state.quote, error, loading: false, retryAt: error ? state.retryAt : 0 };
            publish();
        };
        if (!current.coin || !current.coinSymbol || !current.baseCurrency) {
            finish({ code: "configuration" });
            return;
        }
        /** @param {import('./contracts').Provider} provider @param {string} id @param {boolean} fallback */
        const fetchQuote = (provider, id, fallback) => {
            const spec = provider === "binance" ? Binance.priceRequest(current) : CoinGecko.priceRequest(current, id);
            work.json(spec, current.timeout * 1000, (error, data) => {
                if (error?.code === "unsupported-pair" && provider === "binance") {
                    fetchCoinGecko(true);
                    return;
                }
                if (error) {
                    finish(error);
                    return;
                }
                const result =
                    provider === "binance"
                        ? Binance.parsePrice(data, current.show24hChange)
                        : CoinGecko.parsePrice(data, id, current.baseCurrency);
                const price = numberOrNull(result.price);
                if (price === null || price < 0) {
                    finish({ code: "invalid-response" });
                    return;
                }
                const receivedAt = env.now();
                finish(null, {
                    key: quoteKey(current),
                    price,
                    change24h: current.show24hChange ? numberOrNull(result.change24h) : null,
                    provider,
                    receivedAt,
                    updatedAt: result.updatedAt ?? receivedAt,
                    fallback,
                });
            });
        };
        /** @param {boolean} fallback */
        const fetchCoinGecko = (fallback) => {
            // A canonical CoinGecko ID can be requested directly. Legacy Binance
            // symbol IDs must first be resolved against an unambiguous catalog.
            if (current.coin !== current.coinSymbol) {
                fetchQuote("coingecko", current.coin, fallback);
                return;
            }
            const resolve = () => {
                const identity = CoinGecko.resolveIdentity(current.coin, current.coinSymbol, catalog);
                if (identity.error) finish(identity.error);
                else fetchQuote("coingecko", identity.id, fallback);
            };
            if (catalogUntil > env.now()) {
                resolve();
                return;
            }
            work.json(CoinGecko.catalogRequest(current.apiKey), current.timeout * 1000, (error, data) => {
                if (error) {
                    finish(error);
                    return;
                }
                try {
                    catalog = CoinGecko.parseCatalog(data);
                } catch (_) {
                    finish({ code: "invalid-response" });
                    return;
                }
                catalogUntil = env.now() + 3_600_000;
                resolve();
            });
        };
        if (current.apiProvider === "binance") fetchQuote("binance", current.coin, false);
        else fetchCoinGecko(false);
    }
    return {
        refresh,
        /** @param {Partial<import('./contracts').Settings>} next */
        configure(next) {
            if (disposed) return;
            const normalized = normalizeSettings(next);
            if (JSON.stringify(normalized) === JSON.stringify(settings) && generation > 0) return;
            ++generation;
            active?.cancel();
            active = null;
            if (quoteKey(normalized) !== quoteKey(settings)) state.quote = null;
            if (normalized.apiKey !== settings.apiKey) {
                catalog = [];
                catalogUntil = 0;
            }
            settings = normalized;
            state.loading = false;
            state.error = null;
            publish();
            refresh();
        },
        dispose() {
            disposed = true;
            ++generation;
            active?.cancel();
            active = null;
        },
    };
}

/** @param {import('./contracts').Environment} env */
export function createCatalog(env) {
    /** @type {ReturnType<typeof operation> | null} */
    let active = null;
    let retryAt = 0;
    let generation = 0;
    return {
        /** @param {import('./contracts').Provider} provider @param {string} apiKey
         * @param {(error: import('./contracts').Failure | null, coins?: import('./contracts').Coin[]) => void} done */
        load(provider, apiKey, done) {
            active?.cancel();
            const token = ++generation;
            if (env.now() < retryAt) {
                done({ code: "rate-limit", retryAt });
                return;
            }
            active = operation(env, (deadline) => {
                retryAt = deadline;
            });
            active.json(
                provider === "binance" ? Binance.catalogRequest() : CoinGecko.catalogRequest(apiKey),
                5000,
                (error, data) => {
                    if (token !== generation) return;
                    active = null;
                    if (error) {
                        done(error);
                        return;
                    }
                    try {
                        const coins =
                            provider === "binance" ? Binance.parseCatalog(data) : CoinGecko.parseCatalog(data);
                        retryAt = 0;
                        done(null, coins);
                    } catch (_) {
                        done({ code: "invalid-response" });
                    }
                },
            );
        },
        dispose() {
            ++generation;
            active?.cancel();
            active = null;
        },
    };
}
