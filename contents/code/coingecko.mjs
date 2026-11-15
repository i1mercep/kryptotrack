/** @param {string} apiKey */
function endpoint(apiKey) {
    return apiKey ? "https://pro-api.coingecko.com/api/v3/" : "https://api.coingecko.com/api/v3/";
}
/** @param {string} apiKey @returns {Record<string, string>} */
function headers(apiKey) {
    return apiKey ? { "x-cg-pro-api-key": apiKey } : {};
}
/** @param {import('./contracts').Settings} settings @param {string} id */
export function priceRequest(settings, id) {
    return {
        url: `${endpoint(settings.apiKey)}simple/price?ids=${encodeURIComponent(id)}&vs_currencies=${encodeURIComponent(settings.baseCurrency)}&include_last_updated_at=true${settings.show24hChange ? "&include_24hr_change=true" : ""}`,
        headers: headers(settings.apiKey),
    };
}
/** @param {string} [apiKey] */
export function catalogRequest(apiKey = "") {
    return { url: `${endpoint(apiKey)}coins/list?include_platform=false`, headers: headers(apiKey) };
}
/** @param {unknown} data @param {string} id @param {string} currency */
export function parsePrice(data, id, currency) {
    const item = /** @type {Record<string, Record<string, unknown>>} */ (data)?.[id];
    const timestamp = Number(item?.last_updated_at);
    return {
        price: item?.[currency],
        change24h: item?.[`${currency}_24h_change`],
        updatedAt: Number.isFinite(timestamp) && timestamp > 0 ? timestamp * 1000 : null,
    };
}
/** @param {unknown} data @returns {import('./contracts').Coin[]} */
export function parseCatalog(data) {
    if (!Array.isArray(data)) throw new Error("Invalid catalog");
    return data.filter(
        (item) =>
            item && typeof item.id === "string" && typeof item.symbol === "string" && typeof item.name === "string",
    );
}
/** Exact IDs win; a symbol alone is safe only when unique.
 * @param {string} coin @param {string} symbol @param {import('./contracts').Coin[]} catalog */
export function resolveIdentity(coin, symbol, catalog) {
    const exact = catalog.find((item) => item.id === coin);
    if (exact) return { id: exact.id, error: null };
    const matches = catalog.filter((item) => item.symbol.toLowerCase() === symbol.toLowerCase());
    return matches.length === 1
        ? { id: matches[0].id, error: null }
        : { id: "", error: { code: matches.length > 1 ? "ambiguous" : "unsupported" } };
}
