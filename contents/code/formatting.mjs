/** @param {unknown} value @param {number} fallback @param {number} min @param {number} max */
export function bounded(value, fallback, min, max) {
    const number = value === null || value === undefined || value === "" ? fallback : Number(value);
    return Number.isFinite(number) ? Math.min(max, Math.max(min, Math.trunc(number))) : fallback;
}
/** @param {Record<string, unknown>} config */
export function normalize(config) {
    const standardPriceThreshold = bounded(config.standardPriceThreshold, 1, 0, 1_000_000);
    const minSmallPriceDecimals = bounded(config.minSmallPriceDecimals, 2, 0, 12);
    return {
        standardPriceThreshold,
        largePriceThreshold: Math.max(standardPriceThreshold, bounded(config.largePriceThreshold, 1000, 0, 1_000_000)),
        largePriceDecimals: bounded(config.largePriceDecimals, 0, 0, 12),
        standardPriceDecimals: bounded(config.standardPriceDecimals, 2, 0, 12),
        smallPriceSignificantDigits: bounded(config.smallPriceSignificantDigits, 3, 1, 12),
        minSmallPriceDecimals,
        maxSmallPriceDecimals: Math.max(minSmallPriceDecimals, bounded(config.maxSmallPriceDecimals, 8, 0, 12)),
    };
}
/** @param {number} price @param {Record<string, unknown>} config */
export function formatPrice(price, config) {
    if (!Number.isFinite(price) || price < 0) return "";
    const options = normalize(config);
    let decimals = options.standardPriceDecimals;
    if (price >= options.largePriceThreshold) decimals = options.largePriceDecimals;
    else if (price < options.standardPriceThreshold && price > 0) {
        decimals = Math.min(
            options.maxSmallPriceDecimals,
            Math.max(
                options.minSmallPriceDecimals,
                Math.floor(-Math.log10(price)) + options.smallPriceSignificantDigits,
            ),
        );
    }
    return trimZeros(price.toFixed(decimals));
}
/** @param {string} value */
export function trimZeros(value) {
    return value.replace(/\.0+$/, "").replace(/(\.\d*?[1-9])0+$/, "$1");
}
/** Locale-specific grouping stays in QML, where Qt's Number extension exists.
 * @param {string} value @param {string} decimalPoint @param {(value: number) => string} integerFormatter */
export function localize(value, decimalPoint, integerFormatter) {
    const parts = value.split(".");
    return integerFormatter(Number(parts[0])) + (parts.length > 1 ? decimalPoint + parts[1] : "");
}
