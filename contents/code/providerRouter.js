.import "binance.js" as Binance
.import "coingecko.js" as CoinGecko

function fetchPrice(providerName, coin, coinSymbol, baseCurrency, timeout, apiKey, root) {
    if (normalizeProviderName(providerName) === "coingecko") {
        CoinGecko.fetchPrice(coin, coinSymbol, baseCurrency, timeout, apiKey, root);
        return;
    }

    Binance.fetchPrice(coin, coinSymbol, baseCurrency, timeout, apiKey, root);
}

function fetchCoinsList(providerName, callback, errorCallback) {
    if (normalizeProviderName(providerName) === "coingecko") {
        CoinGecko.fetchCoinsList(callback, errorCallback);
        return;
    }

    Binance.fetchCoinsList(callback, errorCallback);
}

function normalizeProviderName(providerName) {
    return String(providerName || "").trim().toLowerCase();
}