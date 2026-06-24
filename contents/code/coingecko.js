 .import "cachedCoins.js" as CachedCoins

const BASE_API_URL = "https://api.coingecko.com/api/v3/";
const BASE_PRO_API_URL = "https://pro-api.coingecko.com/v3/";
const COINS_LIST_TIMEOUT_MS = 5000;
const COIN_LOOKUP_CACHE_TTL_MS = 60 * 60 * 1000;
const FREE_API_JITTER_MS = 3000;
const MIN_TIMEOUT_MS = 1000;
const DEFAULT_TIMEOUT_S = 10;
const MAX_PRICE_RETRIES = 2;
const RETRY_BASE_DELAY_MS = 1000;
const RETRY_MAX_DELAY_MS = 8000;
var coinLookupById = null;
var coinLookupBySymbol = null;
var coinLookupTimestamp = 0;

/**
 * Fetches the full list of coins from CoinGecko.
 * Used by the config UI to populate the coin selector.
 *
 * @param {function} callback - Called with the parsed coin array on success.
 * @param {function} [errorCallback] - Called with an error message string on failure.
 */
function fetchCoinsList(callback, errorCallback) {
    const url = BASE_API_URL + "coins/list?include_platform=false";
    const xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = COINS_LIST_TIMEOUT_MS;

    xhr.onload = () => {
        if (xhr.status === 200) {
            try {
                const response = JSON.parse(xhr.responseText);
                if (!Array.isArray(response)) {
                    console.error("Unexpected coin list response format");
                    if (errorCallback) errorCallback("Invalid coin data format");
                    return;
                }
                rebuildCoinLookup(response);
                if (callback) callback(response);
            } catch (error) {
                console.error("Error parsing coin list:", error);
                if (errorCallback) errorCallback("Failed to parse coin data");
            }
        } else {
            console.error("Failed to fetch coins list, status:", xhr.status);
            if (errorCallback) errorCallback("Failed to fetch coin data (Status: " + xhr.status + ")");
        }
    };

    xhr.ontimeout = () => {
        console.error("Coins list request timed out");
        if (errorCallback) errorCallback("Request timed out");
    };

    xhr.onerror = () => {
        console.error("Coins list network error");
        if (errorCallback) errorCallback("Network error");
    };

    xhr.send();
}

/**
 * Cancels any pending price request (jitter timer or in-flight XHR) for the
 * given widget instance. Per-instance state is stored directly on `root` as
 * plain JS properties, so no shared module-level variables are needed.
 * Safe to call at any time, even when no request is pending.
 *
 * @param {object} root - The QML root item that owns this request.
 */
function cancelPendingPrice(root) {
    if (root.jitterTimer && root.jitterTimer.stop) {
        root.jitterTimer.stop();
    }
    root._jitterCallback = null;
    if (root._priceXhr != null) {
        var xhr = root._priceXhr;
        root._priceXhr = null;
        // Clear handlers before aborting to prevent stale callbacks
        xhr.onload = undefined;
        xhr.onerror = undefined;
        xhr.ontimeout = undefined;
        xhr.abort();
    }
}

/**
 * Fetches the current price of a cryptocurrency from CoinGecko.
 * Automatically cancels any previous in-flight request for this instance.
 * Per-instance state is stored on `root`, so multiple widget instances never
 * interfere with each other.
 *
 * @param {string} coin - CoinGecko coin ID or a provider-specific legacy value.
 * @param {string} coinSymbol - Display symbol used to recover a CoinGecko ID when switching providers.
 * @param {string} baseCurrency - Target fiat/crypto currency (e.g. "usd").
 * @param {number} timeout - Request timeout in seconds.
 * @param {string} apiKey - CoinGecko Pro API key, or empty for free tier.
 * @param {object} root - QML root item exposing setLoading(), showError(), storePrice(), useCachedPrice().
 */
function fetchPrice(coin, coinSymbol, baseCurrency, timeout, apiKey, root) {
    cancelPendingPrice(root);

    const normalizedCoin = resolveCoinId(coin, coinSymbol);
    const normalizedBaseCurrency = String(baseCurrency || "").trim().toLowerCase();
    const normalizedApiKey = String(apiKey || "").trim();
    const timeoutSec = Number(timeout) || DEFAULT_TIMEOUT_S;
    const timeoutMs = Math.max(MIN_TIMEOUT_MS, timeoutSec * 1000);

    if (normalizedCoin === "" || normalizedBaseCurrency === "") {
        root.showError("Invalid coin or currency");
        root.useCachedPrice();
        return;
    }

    const useProApi = normalizedApiKey !== "";
    const baseUrl = useProApi ? BASE_PRO_API_URL : BASE_API_URL;
    const include24hChange = root.show24hChange === true;
    const url = baseUrl + "simple/price?ids=" + encodeURIComponent(normalizedCoin)
        + "&vs_currencies=" + encodeURIComponent(normalizedBaseCurrency)
        + (include24hChange ? "&include_24hr_change=true" : "");

    // Apply jitter only on the free API to spread requests across widget instances
    // and reduce the chance of synchronized polls hitting the rate limit together.
    // Pro API users have higher quotas and don't need the delay.
    // setTimeout is unavailable in QML JS; use Qt.createQmlObject to make a one-shot Timer.
    const jitterMs = useProApi ? 0 : Math.floor(Math.random() * FREE_API_JITTER_MS);

    const doFetch = attempt => {
        attempt = attempt || 0;
        root.setLoading(true);

        const xhr = new XMLHttpRequest();
        root._priceXhr = xhr;
        xhr.open("GET", url, true);
        xhr.timeout = timeoutMs;
        if (useProApi) {
            xhr.setRequestHeader("x-cg-pro-api-key", normalizedApiKey);
        }

        const fail = (message, useCache) => {
            root.showError(message);
            if (useCache) {
                root.useCachedPrice();
            }
        };

        xhr.onload = () => {
            root._priceXhr = null;

            if (xhr.status === 200) {
                try {
                    const response = JSON.parse(xhr.responseText);
                    const coinData = response && response[normalizedCoin];
                    const price = coinData ? coinData[normalizedBaseCurrency] : undefined;
                    const change24hKey = normalizedBaseCurrency + "_24h_change";
                    const change24h = include24hChange && coinData ? coinData[change24hKey] : undefined;

                    if (price === undefined || price === null || price === "") {
                        fail("Invalid coin or currency", false);
                        return;
                    }

                    root.storePrice(String(price), Date.now(), change24h);
                } catch (error) {
                    console.error("Failed to parse price response:", error);
                    fail("Failed to parse API response", true);
                }
                return;
            }

            if (shouldRetryStatus(xhr.status) && attempt < MAX_PRICE_RETRIES) {
                if (xhr.status === 429) {
                    console.log("Rate limit reached");
                }
                schedulePriceRetry(root, attempt, parseRetryAfterMs(xhr.getResponseHeader ? xhr.getResponseHeader("Retry-After") : ""), doFetch);
                return;
            }

            if (xhr.status === 429) {
                console.log("Rate limit reached");
            }
            fail("API error: " + xhr.status, true);
        };

        xhr.onerror = () => {
            root._priceXhr = null;
            if (attempt < MAX_PRICE_RETRIES) {
                schedulePriceRetry(root, attempt, 0, doFetch);
                return;
            }
            fail("Network error", true);
        };

        xhr.ontimeout = () => {
            root._priceXhr = null;
            if (attempt < MAX_PRICE_RETRIES) {
                schedulePriceRetry(root, attempt, 0, doFetch);
                return;
            }
            fail("Request timed out", true);
        };

        xhr.send();
    };

    if (jitterMs <= 0) {
        doFetch(0);
    } else {
        if (!root.jitterTimer || !root.jitterTimer.start) {
            doFetch(0);
            return;
        }
        root._jitterCallback = function() {
            doFetch(0);
        };
        root.jitterTimer.interval = jitterMs;
        root.jitterTimer.start();
    }
}

function shouldRetryStatus(statusCode) {
    return statusCode === 429 || statusCode >= 500;
}

function schedulePriceRetry(root, attempt, retryAfterMs, retryCallback) {
    var nextAttempt = attempt + 1;
    var delayMs = getRetryDelayMs(attempt, retryAfterMs);
    console.log("Retrying CoinGecko price request in " + delayMs + "ms");

    if (!root.jitterTimer || !root.jitterTimer.start) {
        retryCallback(nextAttempt);
        return;
    }

    root._jitterCallback = function() {
        retryCallback(nextAttempt);
    };
    root.jitterTimer.interval = delayMs;
    root.jitterTimer.start();
}

function getRetryDelayMs(attempt, retryAfterMs) {
    if (isFinite(retryAfterMs) && retryAfterMs > 0) {
        return Math.min(retryAfterMs, 60000);
    }

    return Math.min(RETRY_BASE_DELAY_MS * Math.pow(2, attempt) + Math.floor(Math.random() * 250), RETRY_MAX_DELAY_MS);
}

function parseRetryAfterMs(headerValue) {
    var value = String(headerValue || "").trim();
    if (value === "") {
        return 0;
    }

    var seconds = Number(value);
    if (isFinite(seconds)) {
        return Math.max(0, seconds * 1000);
    }

    var timestamp = Date.parse(value);
    if (isFinite(timestamp)) {
        return Math.max(0, timestamp - Date.now());
    }

    return 0;
}

function resolveCoinId(coin, coinSymbol) {
    var normalizedCoin = String(coin || "").trim().toLowerCase();
    var normalizedCoinSymbol = String(coinSymbol || "").trim().toLowerCase();

    if (normalizedCoin === "" && normalizedCoinSymbol === "") {
        return "";
    }

    ensureCoinLookup();

    if (normalizedCoin !== "" && coinLookupById[normalizedCoin]) {
        return normalizedCoin;
    }

    if (normalizedCoinSymbol !== "" && coinLookupBySymbol[normalizedCoinSymbol]) {
        return String(coinLookupBySymbol[normalizedCoinSymbol].id || "").trim().toLowerCase();
    }

    if (normalizedCoin !== "" && coinLookupBySymbol[normalizedCoin]) {
        return String(coinLookupBySymbol[normalizedCoin].id || "").trim().toLowerCase();
    }

    return normalizedCoin;
}

function ensureCoinLookup() {
    if (coinLookupById !== null && coinLookupBySymbol !== null && Date.now() - coinLookupTimestamp < COIN_LOOKUP_CACHE_TTL_MS) {
        return;
    }

    rebuildCoinLookup(CachedCoins.getCoins());
}

function rebuildCoinLookup(coins) {
    coinLookupById = {};
    coinLookupBySymbol = {};
    coinLookupTimestamp = Date.now();

    for (var i = 0; i < coins.length; i++) {
        var item = coins[i];
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
