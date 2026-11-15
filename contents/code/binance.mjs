const BASE = "https://data-api.binance.vision/api/v3/";

/** @param {import('./contracts').Settings} settings */
export function priceRequest(settings) {
    const symbol = (settings.coinSymbol + settings.baseCurrency).toUpperCase();
    const path = settings.show24hChange ? "ticker/24hr" : "ticker/price";
    return { url: `${BASE}${path}?symbol=${encodeURIComponent(symbol)}` };
}

export function catalogRequest() {
    return { url: `${BASE}exchangeInfo?permissions=%5B%22SPOT%22%5D&showPermissionSets=false&symbolStatus=TRADING` };
}

/** @param {unknown} data @param {boolean} includeChange */
export function parsePrice(data, includeChange) {
    const item = /** @type {{price?: unknown, lastPrice?: unknown, priceChangePercent?: unknown}} */ (data);
    return {
        price: includeChange ? item?.lastPrice : item?.price,
        change24h: includeChange ? item?.priceChangePercent : null,
        updatedAt: null,
    };
}

/** @param {unknown} data @returns {import('./contracts').Coin[]} */
export function parseCatalog(data) {
    const symbols = /** @type {{symbols?: {status: string, baseAsset: string}[]}} */ (data)?.symbols;
    if (!Array.isArray(symbols)) throw new Error("Invalid catalog");
    const assets = new Set(
        symbols
            .filter((item) => item.status === "TRADING" && typeof item.baseAsset === "string")
            .map((item) => item.baseAsset.toLowerCase()),
    );
    return Array.from(assets)
        .sort()
        .map((symbol) => ({ id: symbol, symbol, name: symbol.toUpperCase() }));
}
