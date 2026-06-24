.import "binance.js" as Binance
.import "coingecko.js" as CoinGecko

function fetchPrice(providerName, coin, coinSymbol, baseCurrency, timeout, apiKey, root) {
    var provider = selectProvider(providerName);
    if (provider === "coingecko") {
        CoinGecko.fetchPrice(coin, coinSymbol, baseCurrency, timeout, apiKey, root);
        return;
    }

    Binance.fetchPrice(coin, coinSymbol, baseCurrency, timeout, apiKey, root);
}

function fetchCoinsList(providerName, callback, errorCallback) {
    var provider = selectProvider(providerName);
    if (provider === "coingecko") {
        CoinGecko.fetchCoinsList(callback, errorCallback);
        return;
    }

    Binance.fetchCoinsList(callback, errorCallback);
}

function normalizeProviderName(providerName) {
    return String(providerName || "").trim().toLowerCase();
}

function selectProvider(providerName) {
    var provider = normalizeProviderName(providerName);
    if (provider === "binance" || provider === "coingecko") {
        return provider;
    }

    if (provider !== "") {
        console.warn("Unknown API provider '" + providerName + "', falling back to Binance");
    }
    return "binance";
}