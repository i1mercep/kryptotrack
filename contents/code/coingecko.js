const BASE_API_URL = "https://api.coingecko.com/api/v3/";
const BASE_PRO_API_URL = "https://pro-api.coingecko.com/v3/";

function fetchCoinsList(callback, errorCallback) {
    const url = BASE_API_URL + "coins/list";
    const xhr = new XMLHttpRequest()
    xhr.open("GET", url, true)
    xhr.timeout = 5000 // 5 seconds

    xhr.onreadystatechange = () => {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    const response = JSON.parse(xhr.responseText)
                    callback(response) // Return the list of coins
                } catch (e) {
                    console.error("Error parsing coin list:", e)
                    if (errorCallback) errorCallback("Failed to parse coin data")
                }
            } else {
                console.error("Failed to fetch coins list, status:", xhr.status)
                if (errorCallback) errorCallback("Failed to fetch coin data (Status: " + xhr.status + ")")
            }
        }
    }

    xhr.ontimeout = () => {
        console.error("Request timed out")
        if (errorCallback) errorCallback("Request timed out")
    }

    xhr.onerror = () => {
        console.error("Network error")
        if (errorCallback) errorCallback("Network error")
    }

    xhr.send()
}

function fetchPrice(coin, baseCurrency, timeout, apiKey, root) {
    root.setLoading(true);
    const baseUrl = apiKey == "" ? BASE_API_URL : BASE_PRO_API_URL;
    const url = baseUrl + "simple/price?ids=" + coin + "&vs_currencies=" + baseCurrency;

    const xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = timeout;
    if (baseUrl === BASE_PRO_API_URL) {
        if (apiKey === "") {
            console.error("API key is required for CoinGecko Pro API");
            return;
        }
        xhr.setRequestHeader("X-CMC_PRO_API_KEY", apiKey);
    }

    xhr.onreadystatechange = () => {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            root.setLoading(false);

            if (xhr.status === 200) {
                var response = JSON.parse(xhr.responseText);
                if (response[coin] && response[coin][baseCurrency]) {
                    var price = response[coin][baseCurrency];
                    root.storePrice(price, Date.now());
                } else {
                    root.showError("Invalid coin or currency");
                }
            } else if (xhr.status === 429) {
                console.log("Rate limit reached");
                root.useCachedPrice();
            } else {
                root.showError("API error: " + xhr.status);
            }
        }
    };

    xhr.onerror = () => {
        root.showError("Network error");
        root.useCachedPrice();
    };

    xhr.ontimeout = () => {
        root.showError("Request timeout");
        root.useCachedPrice();
    };

    xhr.send();
}
