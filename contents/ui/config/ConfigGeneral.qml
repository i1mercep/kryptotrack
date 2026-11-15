pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "../../code/cachedCoins.mjs" as CachedCoins
import "../../code/catalog.mjs" as Catalog
import "../../code/http.mjs" as Http
import "../../code/providerRouter.mjs" as Router
import "../models"
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configGeneral

    property var catalog: null
    property string cfg_apiKey: ""
    property string cfg_apiProvider: "binance"
    property string cfg_baseCurrency: "usdt"
    property string cfg_coin: "bitcoin"
    property string cfg_coinSymbol: "btc"
    property int cfg_refreshInterval: 60
    property var coinsList: CachedCoins.getCoins()
    property string errorMessage: ""
    property bool isLoadingCoins: false
    property bool ready: false
    property var requestFunction: function (spec, timeout, done) {
        return Http.request(spec, timeout, done, scheduler.schedule, function () {
            return new XMLHttpRequest();
        }, scheduler.send);
    }
    readonly property string selectedCoinText: {
        const selected = coinsList.find(function (coin) {
            return coin.id === configGeneral.cfg_coin;
        });
        return selected ? selected.name + " (" + cfg_coinSymbol.toUpperCase() + ")" : cfg_coin + " (" + cfg_coinSymbol.toUpperCase() + ") — " + i18n("not in the current catalog");
    }
    property var visibleCoinsList: []
    property var visibleCurrencies: []

    function commitCoinSelection(index: int): void {
        const selected = configGeneral.visibleCoinsList[index];
        if (!selected)
            return;
        configGeneral.cfg_coin = selected.id;
        configGeneral.cfg_coinSymbol = selected.symbol;
    }

    function loadCoins(): void {
        if (!configGeneral.ready)
            return;
        configGeneral.isLoadingCoins = true;
        configGeneral.errorMessage = "";
        configGeneral.coinsList = CachedCoins.getCoins();
        configGeneral.updateVisibleCoinsList();
        configGeneral.catalog.load(configGeneral.cfg_apiProvider, configGeneral.cfg_apiKey, function (error, coins) {
            configGeneral.isLoadingCoins = false;
            if (error) {
                configGeneral.errorMessage = messages.describe(error) + " " + i18n("Using the bundled coin catalog.");
            } else {
                configGeneral.coinsList = configGeneral.cfg_apiProvider === "binance" ? Catalog.enrichBinance(coins, CachedCoins.getCoins()) : coins;
            }
            configGeneral.updateVisibleCoinsList();
        });
    }

    function updateCurrencies(): void {
        const currencies = [];
        for (let i = 0; i < currencyModel.count; ++i) {
            const item = currencyModel.get(i);
            currencies.push({
                id: item.abbreviation,
                symbol: item.abbreviation,
                name: item.name
            });
        }
        configGeneral.visibleCurrencies = Catalog.search(currencies, filterCurrField.text, 0);
    }

    function updateVisibleCoinsList(): void {
        configGeneral.visibleCoinsList = Catalog.search(configGeneral.coinsList, filterCoinsField.text, configGeneral.cfg_apiProvider === "coingecko" ? 2 : 0);
    }

    Component.onCompleted: {
        configGeneral.catalog = Router.createCatalog({
            request: function (spec, timeout, done) {
                return configGeneral.requestFunction(spec, timeout, done);
            },
            schedule: scheduler.schedule,
            now: Date.now,
            random: Math.random,
            changed: function () {}
        });
        configGeneral.ready = true;
        configGeneral.updateCurrencies();
        Qt.callLater(configGeneral.loadCoins);
    }
    Component.onDestruction: {
        if (configGeneral.catalog)
            configGeneral.catalog.dispose();
    }
    onCfg_apiKeyChanged: Qt.callLater(configGeneral.loadCoins)
    onCfg_apiProviderChanged: Qt.callLater(configGeneral.loadCoins)

    RequestScheduler {
        id: scheduler
    }

    StatusMessages {
        id: messages
    }

    CurrencyModel {
        id: currencyModel
    }

    Timer {
        id: coinDebounce

        interval: 150

        onTriggered: configGeneral.updateVisibleCoinsList()
    }

    Timer {
        id: currencyDebounce

        interval: 150

        onTriggered: configGeneral.updateCurrencies()
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            text: configGeneral.errorMessage || i18n("Loading cryptocurrencies…")
            type: configGeneral.errorMessage !== "" ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
            visible: configGeneral.errorMessage !== "" || configGeneral.isLoadingCoins

            actions: [
                Kirigami.Action {
                    enabled: !configGeneral.isLoadingCoins
                    icon.name: "view-refresh"
                    text: i18n("Retry")

                    onTriggered: configGeneral.loadCoins()
                }
            ]
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Selected cryptocurrency:")
            Layout.fillWidth: true
            text: configGeneral.selectedCoinText
            wrapMode: Text.Wrap
        }

        QQC2.SearchField {
            id: filterCoinsField

            Kirigami.FormData.label: i18n("Search cryptocurrencies:")
            Layout.fillWidth: true
            objectName: "coinSearch"
            placeholderText: configGeneral.cfg_apiProvider === "coingecko" ? i18n("Type at least 2 characters…") : i18n("Name or symbol…")
            suggestionModel: configGeneral.visibleCoinsList
            textRole: "name"

            delegate: QQC2.ItemDelegate {
                required property int index
                required property var modelData

                highlighted: filterCoinsField.highlightedIndex === index
                text: modelData.name + " (" + modelData.symbol.toUpperCase() + ")"
                width: filterCoinsField.width
            }

            onActivated: function (index) {
                configGeneral.commitCoinSelection(index);
            }
            onTextChanged: coinDebounce.restart()
        }

        QQC2.Label {
            text: i18n("No matching cryptocurrencies.")
            visible: filterCoinsField.text.length >= 2 && configGeneral.visibleCoinsList.length === 0
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Selected base currency:")
            text: configGeneral.cfg_baseCurrency.toUpperCase()
        }

        QQC2.SearchField {
            id: filterCurrField

            Kirigami.FormData.label: i18n("Search currencies:")
            Layout.fillWidth: true
            objectName: "currencySearch"
            placeholderText: i18n("Name or currency code…")
            suggestionModel: configGeneral.visibleCurrencies
            textRole: "name"

            delegate: QQC2.ItemDelegate {
                required property int index
                required property var modelData

                highlighted: filterCurrField.highlightedIndex === index
                text: modelData.symbol.toUpperCase() + " — " + modelData.name
                width: filterCurrField.width
            }

            onActivated: function (index) {
                const selected = configGeneral.visibleCurrencies[index];
                if (selected)
                    configGeneral.cfg_baseCurrency = selected.id;
            }
            onTextChanged: currencyDebounce.restart()
        }

        QQC2.SpinBox {
            id: refreshInterval

            Kirigami.FormData.label: i18n("Refresh interval (seconds):")
            editable: true
            from: 5
            stepSize: 5
            to: 1000
            value: configGeneral.cfg_refreshInterval

            onValueModified: configGeneral.cfg_refreshInterval = value
        }
    }
}
