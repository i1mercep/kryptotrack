import QtQml

QtObject {
    function describe(error: var): string {
        if (!error)
            return "";
        switch (error.code) {
        case "timeout":
            return i18n("The price service took too long to respond.");
        case "network":
            return i18n("Cannot reach the price service. Check your connection.");
        case "rate-limit":
            return i18n("The price service is busy. Waiting before trying again.");
        case "access":
            return i18n("Access was denied. Check your provider and API key.");
        case "ambiguous":
            return i18n("Several coins use this symbol. Select the exact coin in CoinGecko settings.");
        case "unsupported":
        case "unsupported-pair":
            return i18n("This coin or currency pair is unavailable. Check your selection.");
        case "configuration":
            return i18n("Select a cryptocurrency and base currency in settings.");
        case "invalid-response":
            return i18n("The service did not return a valid price or catalog for this selection.");
        default:
            return i18n("The price service is unavailable. Please try again later.");
        }
    }
}
