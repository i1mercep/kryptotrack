import "../code/providerRouter.js" as ProviderRouter
import "../code/cryptoSymbols.js" as CryptoSymbols
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // General config
    property string coin: Plasmoid.configuration.coin || "bitcoin"
    property string coinSymbol: Plasmoid.configuration.coinSymbol || "btc"
    property string baseCurrency: Plasmoid.configuration.baseCurrency || "usdt"
    property int refreshInterval: Plasmoid.configuration.refreshInterval || 60
    // Appearance config
    property int fontSize: Plasmoid.configuration.fontSize || 9
    property bool useThousandsSeparators: Plasmoid.configuration.useThousandsSeparators
    property int largePriceThreshold: Plasmoid.configuration.largePriceThreshold || 1000
    property int largePriceDecimals: Plasmoid.configuration.largePriceDecimals || 0
    property int standardPriceThreshold: Plasmoid.configuration.standardPriceThreshold || 1
    property int standardPriceDecimals: Plasmoid.configuration.standardPriceDecimals || 2
    property int smallPriceSignificantDigits: Plasmoid.configuration.smallPriceSignificantDigits || 3
    property int minSmallPriceDecimals: Plasmoid.configuration.minSmallPriceDecimals || 2
    property int maxSmallPriceDecimals: Plasmoid.configuration.maxSmallPriceDecimals || 8
    property bool displayBaseCurrency: Plasmoid.configuration.displayBaseCurrency
    property bool boldText: Plasmoid.configuration.boldText
    property bool italicText: Plasmoid.configuration.italicText
    // API config
    property string apiProvider: Plasmoid.configuration.apiProvider || "binance"
    property string apiKey: Plasmoid.configuration.apiKey || ""
    property int timeout: Plasmoid.configuration.timeout || 10
    property string lastPrice
    property string lastUpdated
    property bool isLoading: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string cachedPrice
    property double lastUpdatedTimestamp: 0
    // Internal: used by API providers for request management
    property alias jitterTimer: jitterTimer
    property var _jitterCallback: null
    property var _priceXhr: null
    property string _pendingStatusMessage: ""

    function setLoading(loading) {
        isLoading = loading;
    }

    function fetchPrice() {
        root._pendingStatusMessage = "";
        ProviderRouter.fetchPrice(root.apiProvider, root.coin, root.coinSymbol, root.baseCurrency, timeout, apiKey, root);
    }

    /**
     * @brief Fetches the price of a cryptocurrency when the configuration changes.
     *
     * This function is triggered when there is a change in the coin or base currency configuration
     *
     * @note Sets the loading state to true before making the API call.
     */
    function configChangeFetch() {
        if (root.lastUpdated) {
            console.log("Base currency changed to `" + root.baseCurrency + "` fetching price...");
            fetchPrice();
        }
    }

    function showError(message) {
        var resolvedMessage = message || i18n("Error: Check configuration");
        errorMessage = resolvedMessage;
        statusMessage = resolvedMessage;
        setLoading(false);
    }

    function formatPrice(price) {
        var numericPrice = Number(price);
        if (!isFinite(numericPrice)) {
            return String(price);
        }

        var absolutePrice = Math.abs(numericPrice);
        var decimals = standardPriceDecimals;
        var normalizedLargeThreshold = Math.max(0, largePriceThreshold);
        var normalizedStandardThreshold = Math.max(0, standardPriceThreshold);
        var normalizedLargeDecimals = Math.max(0, largePriceDecimals);
        var normalizedStandardDecimals = Math.max(0, standardPriceDecimals);
        var normalizedMinSmallDecimals = Math.max(0, minSmallPriceDecimals);
        var normalizedMaxSmallDecimals = Math.max(normalizedMinSmallDecimals, maxSmallPriceDecimals);
        var normalizedSmallPriceSignificantDigits = Math.max(1, smallPriceSignificantDigits);

        if (absolutePrice >= normalizedLargeThreshold) {
            decimals = normalizedLargeDecimals;
        } else if (absolutePrice >= normalizedStandardThreshold) {
            decimals = normalizedStandardDecimals;
        } else if (absolutePrice > 0) {
            var leadingZeros = Math.floor(-Math.log(absolutePrice) / Math.LN10);
            decimals = Math.min(normalizedMaxSmallDecimals, Math.max(normalizedMinSmallDecimals, leadingZeros + normalizedSmallPriceSignificantDigits));
        }

        return localizeNumberString(trimTrailingZeros(numericPrice.toFixed(decimals)));
    }

    function trimTrailingZeros(value) {
        return String(value).replace(/\.0+$/, "").replace(/(\.\d*?[1-9])0+$/, "$1");
    }

    function localizeNumberString(value) {
        var stringValue = String(value);
        var parts = stringValue.split(".");
        var locale = Qt.locale();
        var localizedIntegerPart = parts[0];

        if (useThousandsSeparators) {
            localizedIntegerPart = Number(parts[0]).toLocaleString(locale, "f", 0);
        }

        if (parts.length < 2) {
            return localizedIntegerPart;
        }

        return localizedIntegerPart + locale.decimalPoint + parts[1];
    }

    function refreshFormattedPrice() {
        if (cachedPrice) {
            lastPrice = formatPrice(cachedPrice);
        }
    }

    function storePrice(price, timestamp) {
        errorMessage = "";
        statusMessage = root._pendingStatusMessage || "";
        root._pendingStatusMessage = "";
        cachedPrice = String(price);
        lastPrice = formatPrice(cachedPrice);
        setLoading(false);
        lastUpdatedTimestamp = timestamp;
        var date = new Date(timestamp);
        lastUpdated = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
    }

    function useCachedPrice() {
        if (cachedPrice) {
            errorMessage = "";
            lastPrice = formatPrice(cachedPrice);
            var timestamp = lastUpdatedTimestamp || Date.now();
            var date = new Date(timestamp);
            lastUpdated = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat) + " (cached)";
        } else if (!lastPrice) {
            setLoading(true);
        }
    }

    function getPriceText() {
        var crypto_symbol = CryptoSymbols.getCryptoSymbol(root.coin, root.coinSymbol) || root.coinSymbol;
        return crypto_symbol.toUpperCase() + " " + root.lastPrice + (root.displayBaseCurrency ? " " + root.baseCurrency.toUpperCase() : "");
    }

    onApiProviderChanged: {
        fetchPrice();
    }
    onUseThousandsSeparatorsChanged: refreshFormattedPrice()
    onLargePriceThresholdChanged: refreshFormattedPrice()
    onLargePriceDecimalsChanged: refreshFormattedPrice()
    onStandardPriceThresholdChanged: refreshFormattedPrice()
    onStandardPriceDecimalsChanged: refreshFormattedPrice()
    onSmallPriceSignificantDigitsChanged: refreshFormattedPrice()
    onMinSmallPriceDecimalsChanged: refreshFormattedPrice()
    onMaxSmallPriceDecimalsChanged: refreshFormattedPrice()

    Plasmoid.icon: Qt.resolvedUrl("../images/kryptotrack.svg")
    onCoinChanged: {
        configChangeFetch();
    }
    onBaseCurrencyChanged: {
        configChangeFetch();
    }
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.ShadowBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: root.lastPrice ? root.getPriceText() : i18n("Loading...")
    toolTipSubText: {
        var parts = [];
        if (root.lastUpdated)
            parts.push(i18n("Last updated: %1", root.lastUpdated));

        if (root.statusMessage)
            parts.push(root.statusMessage);

        return parts.join("\n");
    }

    Timer {
        id: jitterTimer

        repeat: false
        onTriggered: {
            if (root._jitterCallback) {
                var cb = root._jitterCallback;
                root._jitterCallback = null;
                cb();
            }
        }
    }

    fullRepresentation: Item {
        id: fullRep

        Layout.minimumWidth: priceLabel.implicitWidth + Plasmoid.configuration.fontSize * 2
        Component.onCompleted: {
            fetchPrice();
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.BusyIndicator {
                    id: busyIndicator

                    visible: root.isLoading
                    running: visible
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                PlasmaComponents.Label {
                    id: priceLabel

                    text: root.isLoading ? "" : (root.errorMessage ? root.errorMessage : root.getPriceText())
                    font.pointSize: root.fontSize
                    font.bold: root.boldText
                    font.italic: root.italicText
                }

            }

        }

        Timer {
            id: refreshTimer

            interval: Math.max(5000, root.refreshInterval * 1000)
            running: true
            repeat: true
            onTriggered: {
                console.log("Fetching price for " + root.coin + " vs " + root.baseCurrency);
                fetchPrice();
            }
        }

    }

}
