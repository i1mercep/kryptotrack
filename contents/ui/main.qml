pragma ComponentBehavior: Bound

import QtQuick
import "../code/cryptoSymbols.mjs" as CryptoSymbols
import "../code/formatting.mjs" as Formatting
import "models"
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string assetText: (CryptoSymbols.getCryptoSymbol(config.coin, config.coinSymbol) || config.coinSymbol).toUpperCase()
    readonly property string changeText: prices.quote && prices.quote.change24h !== null ? (prices.quote.change24h > 0 ? "+" : "") + localize(Formatting.trimZeros(prices.quote.change24h.toFixed(2))) + "%" : ""
    readonly property var config: Plasmoid.configuration
    readonly property string displayText: assetText + " " + priceText + (config.displayBaseCurrency ? " " + config.baseCurrency.toUpperCase() : "")
    readonly property var formatOptions: ({
            largePriceThreshold: config.largePriceThreshold,
            largePriceDecimals: config.largePriceDecimals,
            standardPriceThreshold: config.standardPriceThreshold,
            standardPriceDecimals: config.standardPriceDecimals,
            smallPriceSignificantDigits: config.smallPriceSignificantDigits,
            minSmallPriceDecimals: config.minSmallPriceDecimals,
            maxSmallPriceDecimals: config.maxSmallPriceDecimals
        })
    readonly property string priceText: prices.quote ? localize(Formatting.formatPrice(prices.quote.price, formatOptions)) : "—"
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    function localize(value: string): string {
        const locale = Qt.locale();
        return Formatting.localize(value, locale.decimalPoint, function (integer) {
            return root.config.useThousandsSeparators ? integer.toLocaleString(locale, "f", 0) : String(integer);
        });
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.ShadowBackground | PlasmaCore.Types.ConfigurableBackground
    Plasmoid.icon: "view-financial-account"
    preferredRepresentation: fullRepresentation
    toolTipMainText: root.displayText
    toolTipSubText: {
        const parts = [];
        if (prices.quote) {
            parts.push(i18n("Last updated: %1", new Date(prices.quote.updatedAt).toLocaleString(Qt.locale(), Locale.ShortFormat)));
            parts.push(i18n("Source: %1", prices.quote.provider === "binance" ? "Binance" : "CoinGecko"));
            if (prices.quote.fallback)
                parts.push(i18n("Using CoinGecko because this pair is unavailable on Binance."));
            if (root.config.show24hChange && root.changeText)
                parts.push(i18n("24h change: %1", root.changeText));
        }
        if (prices.error)
            parts.push(messages.describe(prices.error));
        else if (prices.loading)
            parts.push(i18n("Updating price…"));
        if (prices.stale)
            parts.push(i18n("Showing the last available price. It may be out of date."));
        if (prices.retryAt > prices.now)
            parts.push(i18n("Next request after %1", new Date(prices.retryAt).toLocaleTimeString(Qt.locale(), Locale.ShortFormat)));
        return parts.join("\n");
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            enabled: prices.canRefresh
            icon.name: "view-refresh"
            text: i18n("Refresh")

            onTriggered: prices.refresh()
        }
    ]
    fullRepresentation: PriceView {
        assetText: root.assetText
        baseCurrencyText: root.config.displayBaseCurrency ? root.config.baseCurrency.toUpperCase() : ""
        boldText: root.config.boldText
        changeText: root.config.show24hChange ? root.changeText : ""
        changeValue: prices.quote ? (prices.quote.change24h ?? 0) : 0
        description: root.toolTipSubText
        hasQuote: prices.quote !== null
        italicText: root.config.italicText
        loading: prices.loading
        pointSize: Formatting.bounded(root.config.fontSize, 9, 4, 72)
        priceText: root.priceText
        vertical: root.vertical
        warningText: prices.error ? messages.describe(prices.error) : prices.stale ? i18n("Price is out of date") : ""
    }

    StatusMessages {
        id: messages
    }

    PriceController {
        id: prices

        settings: ({
                coin: root.config.coin,
                coinSymbol: root.config.coinSymbol,
                baseCurrency: root.config.baseCurrency,
                apiProvider: root.config.apiProvider,
                apiKey: root.config.apiKey,
                timeout: root.config.timeout,
                refreshInterval: root.config.refreshInterval,
                show24hChange: root.config.show24hChange
            })
    }
}
