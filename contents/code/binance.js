.import "cachedCoins.js" as CachedCoins
.import "coingecko.js" as CoinGecko

const BASE_API_URL = "https://data-api.binance.vision/api/v3/";
const EXCHANGE_INFO_URL = BASE_API_URL + "exchangeInfo?permissions=%5B%22SPOT%22%5D&showPermissionSets=false&symbolStatus=TRADING";
const EXCHANGE_INFO_TIMEOUT_MS = 5000;
const MIN_TIMEOUT_MS = 1000;
const DEFAULT_TIMEOUT_S = 10;

var exchangeInfoCache = null;
var exchangeInfoPending = false;
var exchangeInfoCallbacks = [];
var exchangeInfoErrorCallbacks = [];
var coinLookupById = null;
var coinLookupBySymbol = null;

function fetchCoinsList(callback, errorCallback) {
    fetchExchangeInfo(function(symbols) {
        if (callback) {
            callback(buildCoinsList(symbols));
        }
    }, function(errorMessage) {
        if (callback) {
            callback(CachedCoins.getCoins());
        }
        if (errorCallback) {
            errorCallback(errorMessage);
        }
    }, errorCallback);
}

function fetchPrice(coin, coinSymbol, baseCurrency, timeout, apiKey, root) {
    cancelPendingPrice(root);

    const normalizedBaseCurrency = String(baseCurrency || "").trim().toLowerCase();
    const normalizedAssetSymbol = resolveAssetSymbol(coin, coinSymbol);
    const timeoutSec = Number(timeout) || DEFAULT_TIMEOUT_S;
    const timeoutMs = Math.max(MIN_TIMEOUT_MS, timeoutSec * 1000);

    if (normalizedAssetSymbol === "" || normalizedBaseCurrency === "") {
        root.showError("Invalid coin or currency");
        root.useCachedPrice();
        return;
    }

    root.setLoading(true);

    requestTickerPrice(resolveTickerSymbol(normalizedAssetSymbol, normalizedBaseCurrency), timeoutMs, root, function() {
        root._pendingStatusMessage = "Using CoinGecko fallback for unsupported Binance pair";
        CoinGecko.fetchPrice(coin, coinSymbol, normalizedBaseCurrency, timeoutSec, apiKey, root);
    });
}

function cancelPendingPrice(root) {
    if (root.jitterTimer && root.jitterTimer.stop) {
        root.jitterTimer.stop();
    }
    root._jitterCallback = null;
    if (root._priceXhr != null) {
        var xhr = root._priceXhr;
        root._priceXhr = null;
        xhr.onload = undefined;
        xhr.onerror = undefined;
        xhr.ontimeout = undefined;
        xhr.abort();
    }
}

function fetchExchangeInfo(callback, fallbackCallback, errorCallback) {
    if (exchangeInfoCache !== null) {
        if (callback) {
            callback(exchangeInfoCache);
        }
        return;
    }

    if (callback) {
        exchangeInfoCallbacks.push(callback);
    }
    if (errorCallback) {
        exchangeInfoErrorCallbacks.push(errorCallback);
    }
    if (exchangeInfoPending) {
        return;
    }

    exchangeInfoPending = true;

    const xhr = new XMLHttpRequest();
    xhr.open("GET", EXCHANGE_INFO_URL, true);
    xhr.timeout = EXCHANGE_INFO_TIMEOUT_MS;

    xhr.onload = () => {
        exchangeInfoPending = false;

        if (xhr.status === 200) {
            try {
                const response = JSON.parse(xhr.responseText);
                if (!response || !Array.isArray(response.symbols)) {
                    flushExchangeInfoError("Invalid Binance exchange metadata");
                    return;
                }

                exchangeInfoCache = response.symbols;
                flushExchangeInfoSuccess(exchangeInfoCache);
            } catch (error) {
                console.error("Failed to parse Binance exchange metadata:", error, previewResponseText(xhr.responseText));
                if (fallbackCallback) {
                    fallbackCallback("Failed to parse Binance exchange metadata");
                }
                flushExchangeInfoError("Failed to parse Binance exchange metadata");
            }
            return;
        }

        if (fallbackCallback) {
            fallbackCallback("Failed to fetch Binance exchange metadata (Status: " + xhr.status + ")");
        }
        flushExchangeInfoError("Failed to fetch Binance exchange metadata (Status: " + xhr.status + ")");
    };

    xhr.onerror = () => {
        exchangeInfoPending = false;
        if (fallbackCallback) {
            fallbackCallback("Binance network error");
        }
        flushExchangeInfoError("Binance network error");
    };

    xhr.ontimeout = () => {
        exchangeInfoPending = false;
        if (fallbackCallback) {
            fallbackCallback("Binance request timed out");
        }
        flushExchangeInfoError("Binance request timed out");
    };

    xhr.send();
}

function flushExchangeInfoSuccess(symbols) {
    var callbacks = exchangeInfoCallbacks;
    exchangeInfoCallbacks = [];
    exchangeInfoErrorCallbacks = [];

    for (var i = 0; i < callbacks.length; i++) {
        callbacks[i](symbols);
    }
}

function flushExchangeInfoError(message) {
    var callbacks = exchangeInfoErrorCallbacks;
    exchangeInfoCallbacks = [];
    exchangeInfoErrorCallbacks = [];

    for (var i = 0; i < callbacks.length; i++) {
        callbacks[i](message);
    }
}

function buildCoinsList(symbols) {
    ensureCoinLookup();

    var coinsBySymbol = {};

    for (var i = 0; i < symbols.length; i++) {
        var item = symbols[i];
        if (!item || item.status !== "TRADING") {
            continue;
        }

        var baseAsset = String(item.baseAsset || "").trim();
        var quoteAsset = String(item.quoteAsset || "").trim();
        if (baseAsset === "" || quoteAsset === "") {
            continue;
        }

        var normalizedBaseAsset = baseAsset.toLowerCase();
        var normalizedQuoteAsset = quoteAsset.toLowerCase();
        var existing = coinsBySymbol[normalizedBaseAsset];

        if (!existing) {
            var cachedCoin = coinLookupBySymbol[normalizedBaseAsset];
            existing = {
                id: normalizedBaseAsset,
                symbol: normalizedBaseAsset,
                name: cachedCoin ? cachedCoin.name : baseAsset,
                quoteAssets: []
            };
            coinsBySymbol[normalizedBaseAsset] = existing;
        }

        if (existing.quoteAssets.indexOf(normalizedQuoteAsset) === -1) {
            existing.quoteAssets.push(normalizedQuoteAsset);
        }
    }

    var coins = [];
    for (var key in coinsBySymbol) {
        if (Object.prototype.hasOwnProperty.call(coinsBySymbol, key)) {
            coins.push(coinsBySymbol[key]);
        }
    }

    coins.sort(function(left, right) {
        return left.name.localeCompare(right.name);
    });

    return coins;
}

function ensureCoinLookup() {
    if (coinLookupById !== null && coinLookupBySymbol !== null) {
        return;
    }

    coinLookupById = {};
    coinLookupBySymbol = {};

    var cachedCoins = CachedCoins.getCoins();
    for (var i = 0; i < cachedCoins.length; i++) {
        var item = cachedCoins[i];
        var id = String(item.id || "").trim().toLowerCase();
        var symbol = String(item.symbol || "").trim().toLowerCase();

        if (id !== "" && !coinLookupById[id]) {
            coinLookupById[id] = item;
        }
        if (symbol !== "" && !coinLookupBySymbol[symbol]) {
            coinLookupBySymbol[symbol] = item;
        }
    }
}

function resolveAssetSymbol(coin, coinSymbol) {
    var normalizedCoinSymbol = String(coinSymbol || "").trim().toLowerCase();
    if (normalizedCoinSymbol !== "") {
        return normalizedCoinSymbol;
    }

    var normalizedCoin = String(coin || "").trim().toLowerCase();
    if (normalizedCoin === "") {
        return "";
    }

    ensureCoinLookup();
    var cachedCoin = coinLookupById[normalizedCoin];
    if (cachedCoin && cachedCoin.symbol) {
        return String(cachedCoin.symbol).trim().toLowerCase();
    }

    return normalizedCoin;
}

function resolveTradingPair(symbols, assetSymbol, quoteAsset) {
    var normalizedAssetSymbol = String(assetSymbol || "").trim().toUpperCase();
    var normalizedQuoteAsset = String(quoteAsset || "").trim().toUpperCase();

    if (normalizedAssetSymbol === "" || normalizedQuoteAsset === "") {
        return "";
    }

    for (var i = 0; i < symbols.length; i++) {
        var item = symbols[i];
        if (!item || item.status !== "TRADING") {
            continue;
        }

        if (String(item.baseAsset || "").toUpperCase() === normalizedAssetSymbol
                && String(item.quoteAsset || "").toUpperCase() === normalizedQuoteAsset) {
            return String(item.symbol || "").toUpperCase();
        }
    }

    return "";
}

function resolveTickerSymbol(assetSymbol, quoteAsset) {
    var normalizedAssetSymbol = String(assetSymbol || "").trim().toUpperCase();
    var normalizedQuoteAsset = String(quoteAsset || "").trim().toUpperCase();

    if (normalizedAssetSymbol === "" || normalizedQuoteAsset === "") {
        return "";
    }

    return normalizedAssetSymbol + normalizedQuoteAsset;
}

function requestTickerPrice(symbol, timeoutMs, root, unsupportedPairCallback) {
    const url = BASE_API_URL + "ticker/price?symbol=" + encodeURIComponent(symbol) + "&symbolStatus=TRADING";
    const xhr = new XMLHttpRequest();

    root._priceXhr = xhr;
    xhr.open("GET", url, true);
    xhr.timeout = timeoutMs;

    xhr.onload = () => {
        root._priceXhr = null;

        if (xhr.status === 200) {
            try {
                const response = JSON.parse(xhr.responseText);
                const price = response ? response.price : undefined;

                if (price === undefined || price === null || price === "") {
                    root.showError("Invalid Binance price response");
                    root.useCachedPrice();
                    return;
                }

                root.storePrice(String(price), Date.now());
            } catch (error) {
                console.error("Failed to parse Binance price response:", error);
                root.showError("Failed to parse Binance API response");
                root.useCachedPrice();
            }
            return;
        }

        if (isUnsupportedSymbolResponse(xhr.status, xhr.responseText) && unsupportedPairCallback) {
            unsupportedPairCallback();
            return;
        }

        root.showError("Binance API error: " + xhr.status);
        root.useCachedPrice();
    };

    xhr.onerror = () => {
        root._priceXhr = null;
        root.showError("Binance network error");
        root.useCachedPrice();
    };

    xhr.ontimeout = () => {
        root._priceXhr = null;
        root.showError("Binance request timed out");
        root.useCachedPrice();
    };

    xhr.send();
}

function isUnsupportedSymbolResponse(statusCode, responseText) {
    if (statusCode !== 400) {
        return false;
    }

    try {
        var response = JSON.parse(responseText);
        return response && Number(response.code) === -1121;
    } catch (error) {
        return false;
    }
}

function previewResponseText(responseText) {
    return String(responseText || "").slice(0, 160);
}