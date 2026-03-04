const BASE_API_URL = "https://api.coingecko.com/api/v3/";
const BASE_PRO_API_URL = "https://pro-api.coingecko.com/v3/";
const COINS_LIST_TIMEOUT_MS = 5000;
const FREE_API_JITTER_MS = 3000;
const MIN_TIMEOUT_MS = 1000;
const DEFAULT_TIMEOUT_S = 10;

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
 * @param {string} coin - CoinGecko coin ID (e.g. "bitcoin").
 * @param {string} baseCurrency - Target fiat/crypto currency (e.g. "usd").
 * @param {number} timeout - Request timeout in seconds.
 * @param {string} apiKey - CoinGecko Pro API key, or empty for free tier.
 * @param {object} root - QML root item exposing setLoading(), showError(), storePrice(), useCachedPrice().
 */
function fetchPrice(coin, baseCurrency, timeout, apiKey, root) {
    cancelPendingPrice(root);

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
    // setTimeout is unavailable in QML JS; use Qt.createQmlObject to make a one-shot Timer.
    const jitterMs = useProApi ? 0 : Math.floor(Math.random() * FREE_API_JITTER_MS);

    const doFetch = () => {
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

                    if (price === undefined || price === null || price === "") {
                        fail("Invalid coin or currency", false);
                        return;
                    }

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
            root._priceXhr = null;
            fail("Network error", true);
        };

        xhr.ontimeout = () => {
            root._priceXhr = null;
            fail("Request timed out", true);
        };

        xhr.send();
    };

    if (jitterMs <= 0) {
        doFetch();
    } else {
        if (!root.jitterTimer || !root.jitterTimer.start) {
            doFetch();
            return;
        }
        root._jitterCallback = doFetch;
        root.jitterTimer.interval = jitterMs;
        root.jitterTimer.start();
    }
}
