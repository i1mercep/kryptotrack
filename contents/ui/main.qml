import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import "../code/coingecko.js" as CoinGecko
import "../code/cryptoSymbols.js" as CryptoSymbols

PlasmoidItem {
    id: root
    Plasmoid.icon: Qt.resolvedUrl("../images/kryptotrack.svg")

    // General config
    property string coin: Plasmoid.configuration.coin || "bitcoin"
    property string coinSymbol: Plasmoid.configuration.coinSymbol || "btc"
    property string baseCurrency: Plasmoid.configuration.baseCurrency || "usd"
    property int refreshInterval: Plasmoid.configuration.refreshInterval || 60
    // Appearance config
    property int fontSize: Plasmoid.configuration.fontSize || 9
    property bool displayBaseCurrency: Plasmoid.configuration.displayBaseCurrency || false
    property bool boldText: Plasmoid.configuration.boldText || false
    property bool italicText: Plasmoid.configuration.italicText || false
    // API config
    property string apiProvider: Plasmoid.configuration.apiProvider || "coingecko"
    property string apiKey: Plasmoid.configuration.apiKey || ""
    property int timeout: Plasmoid.configuration.timeout || 10

    property string lastPrice
    property string lastUpdated
    property bool isLoading: false
    property string errorMessage: ""
    property string cachedPrice

    onCoinChanged: {
        configChangeFetch();
    }
    onBaseCurrencyChanged: {
        configChangeFetch();
    }

    function setLoading(loading) {
        isLoading = loading;
    }

    function fetchPrice() {
        CoinGecko.fetchPrice(root.coin, root.baseCurrency, timeout, apiKey, root);
    }

    /**
     * @brief Fetches the price of a cryptocurrency when the configuration changes.
     *
     * This function is triggered when there is a change in the coion or base currency configuration
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
        errorMessage = message || "Error: Check configuration";
        setLoading(false);
    }

    function storePrice(price, timestamp) {
        errorMessage = "";
        lastPrice = price;
        setLoading(false);
        var date = new Date(timestamp);
        lastUpdated = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
    }

    function useCachedPrice() {
        if (cachedPrice) {
            lastPrice = cachedPrice;
            var timestamp = lastUpdated || Date.now();
            var date = new Date(timestamp);
            lastUpdated = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat) + " (cached)";
        }
        else if (!lastPrice) {
            setLoading(true);
        }
    }

    function getPriceText() {
        var crypto_symbols = CryptoSymbols.getCryptoSymbols();
        var crypto_symbol = crypto_symbols[root.coin.toLowerCase()] || root.coinSymbol;
        var base_currency = root.displayBaseCurrency ? " " + root.baseCurrency.toUpperCase() : "";
        return crypto_symbol.toUpperCase() + " " + root.lastPrice + (root.displayBaseCurrency ? " " + root.baseCurrency.toUpperCase() : "");
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.ShadowBackground | PlasmaCore.Types.ConfigurableBackground

    fullRepresentation: Item {
        id: fullRep
        Layout.preferredHeight: Plasmoid.configuration.fontSize
        Layout.minimumWidth: priceLabel.implicitWidth + Plasmoid.configuration.fontSize * 2
        Component.onCompleted: {
            if (root.apiProvider != "coingecko") {
                root.showError("API provider not supported");
                return;
            }
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
            interval: Plasmoid.configuration.refreshInterval * 1000 || 60000
            running: true
            repeat: true
            onTriggered: {
                console.log("Fetching price for " + root.coin + " vs " + root.baseCurrency);
                fetchPrice();
            }
        }
    }
}
