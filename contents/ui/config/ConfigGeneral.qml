import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "../models"
import "../../code/coingecko.js" as CoinGecko
import "../../code/cachedCoins.js" as CachedCoins


KCM.SimpleKCM {
    id: configGeneral

    CurrencyModel {
        id: currencyModel
    }

    QtObject {
        id: coinObj
        property var cid
        property var name
        property var symbol
    }

    QtObject {
        id: baseCurrencyObj
        property var name
        property var abbreviation: "usd"
        property var symbol
    }

    QtObject {
        id: refreshIntervalObj
        property var value
    }

    // Config properties
    property alias cfg_coin: coinObj.cid
    property alias cfg_coinSymbol: coinObj.symbol
    property alias cfg_baseCurrency: baseCurrencyObj.symbol
    property alias cfg_refreshInterval: refreshIntervalObj.value

    property var coinsList: CachedCoins.getCoins()
    property bool isLoadingCoins: false
    property string errorMessage: ""


    Kirigami.FormLayout {
        id: formLayout
        anchors.fill: parent

        // Fetch coins and currencies on component load
        Component.onCompleted: {
            errorMessage = ""
            isLoadingCoins = true
            CoinGecko.fetchCoinsList(function(coins) {
                coinsList = coins
                isLoadingCoins = false
                coinSelector.currentIndex = coinsList.findIndex(coin => coin.id === cfg_coin)
            }, function(error) {
                errorMessage = error
                if (error.indexOf("429") !== -1) {
                    errorMessage += " rate limit reached"
                }
                isLoadingCoins = false
            })
        }

        Kirigami.InlineMessage {
            id: statusMessage
            Layout.fillWidth: true
            visible: errorMessage !== "" || isLoadingCoins
            type: errorMessage !== "" ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: errorMessage !== "" ? errorMessage : (isLoadingCoins ? "Loading cryptocurrencies..." : "")
        }

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Label {
                text: "Cryptocurrency [" + configGeneral.cfg_coin + "]" 
                font.bold: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                TextField {
                    id: filterCoinsField
                    placeholderText: "Filter coins"
                    width: 200
                    onTextChanged: {
                        var query = text.toLowerCase()
                        if (query.length < 2) {
                            coinSelector.model = coinsList
                        } else {
                            coinSelector.model = coinsList.filter(function(coin) {
                                return coin.name.toLowerCase().indexOf(query) >= 0 
                                    || coin.symbol.toLowerCase().indexOf(query) >= 0
                            })
                        }
                    }
                }
                ComboBox {
                    id: coinSelector
                    enabled: !isLoadingCoins
                    model: coinsList == [] ? coinModel : coinsList
                    textRole: "name"
                    valueRole: "id"
                    displayText: currentText
                    Layout.fillWidth: true
                    onActivated: {
                        coinObj.cid = model[currentIndex].id
                        coinObj.name = model[currentIndex].name
                        coinObj.symbol = model[currentIndex].symbol
                        console.log("Selected coin: " + model[currentIndex].id + " (" + model[currentIndex].name + ")")
                    }
                    Component.onCompleted: {
                        // console.log("Index of value: " + indexOfValue(cfg_coin), "Coin: " + cfg_coin)
                        // currentIndex = indexOfValue(cfg_coin)
                    }
                }
            }

            Label {
                text: "\nBase currency [" + configGeneral.cfg_baseCurrency + "]"
                font.bold: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                TextField {
                    id: filterCurrField
                    placeholderText: "Filter base currencies"
                    width: 200
                    onTextChanged: {
                        var query = text.toLowerCase()
                        if (query.length < 2) {
                            baseCurrency.model = currencyModel
                        } else {
                            baseCurrency.model = currencyModel.filter(function(curr) {
                                return curr.toLowerCase().indexOf(query) >= 0
                            })
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
                        baseCurrencyObj.abbreviation = currentText
                        baseCurrencyObj.symbol = currencyModel.get(currentIndex).symbol
                        console.log("Selected baseCurrency: " + currentText)
                    }
                    Component.onCompleted: currentIndex = indexOfValue(baseCurrencyObj.abbreviation)
                    delegate: ItemDelegate {
                        text: model.abbreviation.toUpperCase()
                    }
                }
            }

            Label {
                text: "\n Refresh interval (seconds)"
                font.bold: true
            }
            SpinBox {
                id: refreshInterval
                value: cfg_refreshInterval
                from: 5
                to: 1000
                stepSize: 5
                onValueModified: {
                    refreshIntervalObj.value = value
                    console.log("Set refresh interval: " + value + " seconds")
                }
            }
        }
    }
}