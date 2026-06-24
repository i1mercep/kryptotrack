import "../../code/cachedCoins.js" as CachedCoins
import "../../code/providerRouter.js" as ProviderRouter
import "../models"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configGeneral

    // Config properties
    property alias cfg_coin: coinObj.cid
    property alias cfg_coinSymbol: coinObj.symbol
    property alias cfg_baseCurrency: baseCurrencyObj.abbreviation
    property alias cfg_refreshInterval: refreshIntervalObj.value
    property string cfg_apiProvider: "binance"
    property var coinsList: CachedCoins.getCoins()
    property var visibleCoinsList: []
    property bool isLoadingCoins: false
    property string errorMessage: ""

    CurrencyModel {
        id: currencyModel
    }

    QtObject {
        id: coinObj

        property string cid
        property string name
        property string symbol
    }

    QtObject {
        id: baseCurrencyObj

        property string name
        property string abbreviation: "usdt"
        property string symbol
    }

    QtObject {
        id: refreshIntervalObj

        property int value
    }

    function applySelectedCoinState(nextCoinsList) {
        if (!nextCoinsList || nextCoinsList.length === 0) {
            visibleCoinsList = [];
            coinSelector.currentIndex = -1;
            return;
        }

        var selectedIndex = findSelectedCoinIndex(nextCoinsList);
        if (selectedIndex < 0) {
            selectedIndex = 0;
        }

        coinObj.cid = nextCoinsList[selectedIndex].id;
        coinObj.name = nextCoinsList[selectedIndex].name;
        coinObj.symbol = nextCoinsList[selectedIndex].symbol;

        updateVisibleCoinsList();

        var visibleIndex = findSelectedCoinIndex(visibleCoinsList);
        coinSelector.currentIndex = visibleIndex >= 0 ? visibleIndex : 0;
    }

    function commitCoinSelection(index) {
        var selectedIndex = Number(index);
        if (!Array.isArray(visibleCoinsList) || visibleCoinsList.length === 0) {
            return;
        }

        if (!isFinite(selectedIndex) || selectedIndex < 0 || selectedIndex >= visibleCoinsList.length) {
            selectedIndex = 0;
        }

        var selectedCoin = visibleCoinsList[selectedIndex];
        if (!selectedCoin) {
            return;
        }

        coinSelector.currentIndex = selectedIndex;
        coinObj.cid = selectedCoin.id;
        coinObj.name = selectedCoin.name;
        coinObj.symbol = selectedCoin.symbol;
    }

    function findSelectedCoinIndex(nextCoinsList) {
        var normalizedCoin = String(cfg_coin || "").toLowerCase();
        var normalizedCoinSymbol = String(cfg_coinSymbol || "").toLowerCase();
        var isBinanceProvider = String(cfg_apiProvider || "").toLowerCase() === "binance";

        for (var i = 0; i < nextCoinsList.length; i++) {
            var coin = nextCoinsList[i];
            if (!coin) {
                continue;
            }

            var normalizedId = String(coin.id || "").toLowerCase();
            var normalizedSymbol = String(coin.symbol || "").toLowerCase();

            if (normalizedId === normalizedCoin) {
                return i;
            }
            if (normalizedSymbol !== "" && normalizedSymbol === normalizedCoinSymbol) {
                return i;
            }
            if (isBinanceProvider && normalizedSymbol !== "" && normalizedSymbol === normalizedCoin) {
                return i;
            }
        }

        return -1;
    }

    function loadCoins() {
        errorMessage = "";
        isLoadingCoins = true;

        ProviderRouter.fetchCoinsList(cfg_apiProvider, function(coins) {
            coinsList = coins;
            isLoadingCoins = false;
            applySelectedCoinState(coins);
        }, function(error) {
            errorMessage = error;
            if (error.indexOf("429") !== -1)
                errorMessage += " — " + i18n("rate limit reached");

            isLoadingCoins = false;
        });
    }

    function updateVisibleCoinsList() {
        var nextCoinsList = Array.isArray(coinsList) ? coinsList : [];
        var query = String(filterCoinsField.text || "").toLowerCase();
        var isCoinGeckoProvider = String(cfg_apiProvider || "").toLowerCase() === "coingecko";

        if (nextCoinsList.length === 0) {
            visibleCoinsList = [];
            return;
        }

        if (query.length >= 2) {
            visibleCoinsList = nextCoinsList.filter(function(coin) {
                return coin.name.toLowerCase().indexOf(query) >= 0 || coin.symbol.toLowerCase().indexOf(query) >= 0;
            });
            return;
        }

        if (isCoinGeckoProvider) {
            var selectedIndex = findSelectedCoinIndex(nextCoinsList);
            visibleCoinsList = selectedIndex >= 0 ? [nextCoinsList[selectedIndex]] : [];
            return;
        }

        visibleCoinsList = nextCoinsList;
    }

    onCfg_apiProviderChanged: loadCoins()

    Kirigami.FormLayout {
        id: formLayout

        anchors.fill: parent
        // Fetch coins and currencies on component load
        Component.onCompleted: {
            loadCoins();
        }

        Kirigami.InlineMessage {
            id: statusMessage

            Layout.fillWidth: true
            visible: errorMessage !== "" || isLoadingCoins
            type: errorMessage !== "" ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: errorMessage !== "" ? errorMessage : (isLoadingCoins ? i18n("Loading cryptocurrencies…") : "")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !isLoadingCoins && errorMessage === "" && String(cfg_apiProvider || "").toLowerCase() === "coingecko" && filterCoinsField.text.length < 2
            type: Kirigami.MessageType.Information
            text: i18n("Type at least 2 characters to search the CoinGecko coin list.")
        }

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            Label {
                text: i18n("Cryptocurrency") + " [" + configGeneral.cfg_coin + "]"
                font.bold: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                TextField {
                    id: filterCoinsField

                    placeholderText: String(cfg_apiProvider || "").toLowerCase() === "coingecko" ? i18n("Search CoinGecko coins…") : i18n("Filter coins…")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    onTextChanged: {
                        updateVisibleCoinsList();
                        var selectedIndex = findSelectedCoinIndex(visibleCoinsList);
                        coinSelector.currentIndex = selectedIndex >= 0 ? selectedIndex : 0;
                    }
                    onAccepted: commitCoinSelection(coinSelector.currentIndex)
                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            commitCoinSelection(coinSelector.currentIndex);
                        }
                    }
                }

                ComboBox {
                    id: coinSelector

                    enabled: !isLoadingCoins
                    model: visibleCoinsList
                    textRole: "name"
                    valueRole: "id"
                    displayText: currentText
                    Layout.fillWidth: true
                    onActivated: {
                        commitCoinSelection(currentIndex);
                    }
                    Component.onCompleted: {
                        applySelectedCoinState(coinsList);
                    }
                }

            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            Label {
                text: i18n("Base currency") + " [" + configGeneral.cfg_baseCurrency.toUpperCase() + "]"
                font.bold: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                TextField {
                    id: filterCurrField

                    placeholderText: i18n("Filter currencies…")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    onTextChanged: {
                        var query = text.toLowerCase();
                        if (query.length < 2) {
                            baseCurrency.model = currencyModel;
                        } else {
                            var filtered = [];
                            for (var i = 0; i < currencyModel.count; i++) {
                                var item = currencyModel.get(i);
                                if (item.abbreviation.toLowerCase().indexOf(query) >= 0 || item.name.toLowerCase().indexOf(query) >= 0)
                                    filtered.push(item);

                            }
                            baseCurrency.model = filtered;
                        }
                    }
                }

                ComboBox {
                    id: baseCurrency

                    model: currencyModel
                    textRole: "abbreviation"
                    valueRole: "abbreviation"
                    displayText: currentText.toUpperCase()
                    Layout.fillWidth: true
                    onActivated: {
                        baseCurrencyObj.abbreviation = currentValue;
                        // Look up symbol from original model by abbreviation
                        for (var i = 0; i < currencyModel.count; i++) {
                            if (currencyModel.get(i).abbreviation === currentValue) {
                                baseCurrencyObj.symbol = currencyModel.get(i).symbol;
                                break;
                            }
                        }
                    }
                    Component.onCompleted: currentIndex = indexOfValue(baseCurrencyObj.abbreviation)

                    delegate: ItemDelegate {
                        text: model.abbreviation.toUpperCase()
                    }

                }

            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            Label {
                text: i18n("Refresh interval (seconds)")
                font.bold: true
            }

            SpinBox {
                id: refreshInterval

                value: cfg_refreshInterval
                from: 5
                to: 1000
                stepSize: 5
                onValueModified: {
                    refreshIntervalObj.value = value;
                }
            }

        }

    }

}
