import "../code/coingecko.js" as CoinGecko
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
    property string baseCurrency: Plasmoid.configuration.baseCurrency || "usd"
    property int refreshInterval: Plasmoid.configuration.refreshInterval || 60
    // Appearance config
    property int fontSize: Plasmoid.configuration.fontSize || 9
    property bool displayBaseCurrency: Plasmoid.configuration.displayBaseCurrency
    property bool boldText: Plasmoid.configuration.boldText
    property bool italicText: Plasmoid.configuration.italicText
    // API config
    property string apiProvider: Plasmoid.configuration.apiProvider || "coingecko"
    property string apiKey: Plasmoid.configuration.apiKey || ""
    property int timeout: Plasmoid.configuration.timeout || 10
    property string lastPrice
    property string lastUpdated
    property bool isLoading: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string cachedPrice
    property double lastUpdatedTimestamp: 0
    // Internal: used by coingecko.js for request management
    property alias jitterTimer: jitterTimer
    property var _jitterCallback: null
    property var _priceXhr: null

    function setLoading(loading) {
        isLoading = loading;
    }

    function fetchPrice() {
        if (root.apiProvider !== "coingecko") {
            root.showError(i18n("API provider not supported"));
            return ;
        }
        CoinGecko.fetchPrice(root.coin, root.baseCurrency, timeout, apiKey, root);
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

    function storePrice(price, timestamp) {
        errorMessage = "";
        statusMessage = "";
        lastPrice = price;
        cachedPrice = price;
        setLoading(false);
        lastUpdatedTimestamp = timestamp;
        var date = new Date(timestamp);
        lastUpdated = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
    }

    function useCachedPrice() {
        if (cachedPrice) {
            errorMessage = "";
            lastPrice = cachedPrice;
            var timestamp = lastUpdatedTimestamp || Date.now();
            var date = new Date(timestamp);
            lastUpdated = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat) + " (cached)";
        } else if (!lastPrice) {
            setLoading(true);
        }
    }

    function getPriceText() {
        var crypto_symbols = CryptoSymbols.getCryptoSymbols();
        var crypto_symbol = crypto_symbols[root.coin.toLowerCase()] || root.coinSymbol;
        return crypto_symbol.toUpperCase() + " " + root.lastPrice + (root.displayBaseCurrency ? " " + root.baseCurrency.toUpperCase() : "");
    }

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
