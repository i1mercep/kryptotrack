import "../../code/cachedCoins.js" as CachedCoins
import "../../code/coingecko.js" as CoinGecko
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
    property var coinsList: CachedCoins.getCoins()
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
        property string abbreviation: "usd"
        property string symbol
    }

    QtObject {
        id: refreshIntervalObj

        property int value
    }

    Kirigami.FormLayout {
        id: formLayout

        anchors.fill: parent
        // Fetch coins and currencies on component load
        Component.onCompleted: {
            errorMessage = "";
            isLoadingCoins = true;
            CoinGecko.fetchCoinsList(function(coins) {
                coinsList = coins;
                isLoadingCoins = false;
                coinSelector.currentIndex = coinsList.findIndex((coin) => {
                    return coin.id === cfg_coin;
                });
                if (coinSelector.currentIndex >= 0) {
                    coinObj.cid = coinsList[coinSelector.currentIndex].id;
                    coinObj.name = coinsList[coinSelector.currentIndex].name;
                    coinObj.symbol = coinsList[coinSelector.currentIndex].symbol;
                }
            }, function(error) {
                errorMessage = error;
                if (error.indexOf("429") !== -1)
                    errorMessage += " — " + i18n("rate limit reached");

                isLoadingCoins = false;
            });
        }

        Kirigami.InlineMessage {
            id: statusMessage

            Layout.fillWidth: true
            visible: errorMessage !== "" || isLoadingCoins
            type: errorMessage !== "" ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: errorMessage !== "" ? errorMessage : (isLoadingCoins ? i18n("Loading cryptocurrencies…") : "")
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

                    placeholderText: i18n("Filter coins…")
                    width: 200
                    onTextChanged: {
                        var query = text.toLowerCase();
                        if (query.length < 2)
                            coinSelector.model = coinsList;
                        else
                            coinSelector.model = coinsList.filter(function(coin) {
                            return coin.name.toLowerCase().indexOf(query) >= 0 || coin.symbol.toLowerCase().indexOf(query) >= 0;
                        });
                    }
                }

                ComboBox {
                    id: coinSelector

                    enabled: !isLoadingCoins
                    model: coinsList
                    textRole: "name"
                    valueRole: "id"
                    displayText: currentText
                    Layout.fillWidth: true
                    onActivated: {
                        coinObj.cid = model[currentIndex].id;
                        coinObj.name = model[currentIndex].name;
                        coinObj.symbol = model[currentIndex].symbol;
                    }
                    Component.onCompleted: {
                        currentIndex = coinsList.findIndex((coin) => {
                            return coin.id === cfg_coin;
                        });
                        if (currentIndex >= 0) {
                            coinObj.cid = model[currentIndex].id;
                            coinObj.name = model[currentIndex].name;
                            coinObj.symbol = model[currentIndex].symbol;
                        }
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
                    width: 200
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
