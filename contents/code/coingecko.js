const BASE_API_URL = "https://api.coingecko.com/api/v3/";
const BASE_PRO_API_URL = "https://pro-api.coingecko.com/v3/";
const COINS_LIST_TIMEOUT_MS = 3000;
const FREE_API_JITTER_MS = 3000;
const MIN_TIMEOUT_MS = 1000;
const DEFAULT_TIMEOUT_S = 10;

// Track in-flight price request so we can cancel it on re-fetch
var _priceXhr = null;
var _jitterTimer = null;

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
 * Fetches the current price of a cryptocurrency from CoinGecko.
 * Automatically cancels any previous in-flight price request.
 *
 * @param {string} coin - CoinGecko coin ID (e.g. "bitcoin").
 * @param {string} baseCurrency - Target fiat/crypto currency (e.g. "usd").
 * @param {number} timeout - Request timeout in seconds.
 * @param {string} apiKey - CoinGecko Pro API key, or empty for free tier.
 * @param {object} root - QML root item exposing setLoading(), showError(), storePrice(), useCachedPrice().
 */
function fetchPrice(coin, baseCurrency, timeout, apiKey, root) {
    cancelPendingPrice();

    const normalizedCoin = String(coin || "").trim().toLowerCase();
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
    const url = baseUrl + "simple/price?ids=" + encodeURIComponent(normalizedCoin)
        + "&vs_currencies=" + encodeURIComponent(normalizedBaseCurrency);

    // Apply jitter only on the free API to spread requests across widget instances
    // and reduce the chance of synchronized polls hitting the rate limit together.
    // Pro API users have higher quotas and don't need the delay.
    const jitterMs = useProApi ? 0 : Math.random() * FREE_API_JITTER_MS;

    _jitterTimer = setTimeout(() => {
        _jitterTimer = null;
        root.setLoading(true);

        const xhr = new XMLHttpRequest();
        _priceXhr = xhr;
        xhr.open("GET", url, true);
        xhr.timeout = timeoutMs;
        if (useProApi) {
            xhr.setRequestHeader("x-cg-pro-api-key", normalizedApiKey);
        }

        const fail = (message, useCache) => {
            root.setLoading(false);
            root.showError(message);
            if (useCache) {
                root.useCachedPrice();
            }
        };

        xhr.onload = () => {
            _priceXhr = null;

            if (xhr.status === 200) {
                try {
                    const response = JSON.parse(xhr.responseText);
                    const coinData = response && response[normalizedCoin];
                    const price = coinData ? coinData[normalizedBaseCurrency] : undefined;

                    if (price === undefined || price === null || price === "") {
                        fail("Invalid coin or currency", false);
                        return;
                    }

                    root.setLoading(false);
                    root.storePrice(String(price), Date.now());
                } catch (error) {
                    console.error("Failed to parse price response:", error);
                    fail("Failed to parse API response", true);
                }
                return;
            }

            if (xhr.status === 429) {
                console.log("Rate limit reached");
            }
            fail("API error: " + xhr.status, true);
        };

        xhr.onerror = () => {
            _priceXhr = null;
            fail("Network error", true);
        };

        xhr.ontimeout = () => {
            _priceXhr = null;
            fail("Request timeout", true);
        };

        xhr.send();
    }, jitterMs);
}

/**
 * Cancels any pending price request (jitter delay or in-flight XHR).
 * Safe to call at any time, even when no request is pending.
 */
function cancelPendingPrice() {
    if (_jitterTimer !== null) {
        clearTimeout(_jitterTimer);
        _jitterTimer = null;
    }
    if (_priceXhr !== null) {
        var xhr = _priceXhr;
        _priceXhr = null;
        // Clear handlers before aborting to prevent stale callbacks
        xhr.onload = undefined;
        xhr.onerror = undefined;
        xhr.ontimeout = undefined;
        xhr.abort();
    }
}
