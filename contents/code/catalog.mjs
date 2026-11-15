/** @param {import('./contracts').Coin[]} coins @param {string} query @param {number} minimum */
export function search(coins, query, minimum) {
    const needle = query.trim().toLowerCase();
    if (needle.length < minimum) return [];
    return coins.filter(
        (coin) =>
            coin.name.toLowerCase().includes(needle) ||
            coin.symbol.toLowerCase().includes(needle) ||
            coin.id.toLowerCase().includes(needle),
    );
}
/** Give Binance assets canonical IDs only when the bundled mapping is unique.
 * @param {import('./contracts').Coin[]} coins @param {import('./contracts').Coin[]} bundled */
export function enrichBinance(coins, bundled) {
    /** @type {Map<string, import('./contracts').Coin | null>} */
    const symbols = new Map();
    for (const coin of bundled) {
        const symbol = coin.symbol.toLowerCase();
        symbols.set(symbol, symbols.has(symbol) ? null : coin);
    }
    return coins
        .map((coin) => symbols.get(coin.symbol) ?? coin)
        .sort((left, right) => left.name.localeCompare(right.name));
}
