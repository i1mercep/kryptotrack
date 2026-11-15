import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../code/formatting.mjs" as Formatting
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configAppearance

    property alias cfg_boldText: boldText.checked
    property alias cfg_displayBaseCurrency: displayBaseCurrency.checked
    property alias cfg_fontSize: fontSize.value
    property alias cfg_italicText: italicText.checked
    property alias cfg_largePriceDecimals: largePriceDecimals.value
    property alias cfg_largePriceThreshold: largePriceThreshold.value
    property alias cfg_maxSmallPriceDecimals: maxSmallPriceDecimals.value
    property alias cfg_minSmallPriceDecimals: minSmallPriceDecimals.value
    property alias cfg_show24hChange: show24hChange.checked
    property alias cfg_smallPriceSignificantDigits: smallPriceSignificantDigits.value
    property alias cfg_standardPriceDecimals: standardPriceDecimals.value
    property alias cfg_standardPriceThreshold: standardPriceThreshold.value
    property alias cfg_useThousandsSeparators: useThousandsSeparators.checked

    function preview(price: double): string {
        const raw = Formatting.formatPrice(price, {
            largePriceThreshold: largePriceThreshold.value,
            largePriceDecimals: largePriceDecimals.value,
            standardPriceThreshold: standardPriceThreshold.value,
            standardPriceDecimals: standardPriceDecimals.value,
            smallPriceSignificantDigits: smallPriceSignificantDigits.value,
            minSmallPriceDecimals: minSmallPriceDecimals.value,
            maxSmallPriceDecimals: maxSmallPriceDecimals.value
        });
        const locale = Qt.locale();
        return Formatting.localize(raw, locale.decimalPoint, function (integer) {
            return useThousandsSeparators.checked ? integer.toLocaleString(locale, "f", 0) : String(integer);
        });
    }

    Kirigami.FormLayout {
        id: formLayout

        SpinBox {
            id: fontSize

            Kirigami.FormData.label: i18n("Font size")
            editable: true
            from: 4
            stepSize: 1
            to: 72
        }

        CheckBox {
            id: useThousandsSeparators

            Kirigami.FormData.label: i18n("Number formatting")
            text: i18n("Use locale-specific thousands separators")
        }

        CheckBox {
            id: displayBaseCurrency

            Kirigami.FormData.label: i18n("Display base currency")
        }

        CheckBox {
            id: show24hChange

            Kirigami.FormData.label: i18n("Display 24h change")
            text: i18n("Show 24h percentage change")
        }

        CheckBox {
            id: boldText

            Kirigami.FormData.label: i18n("Bold text")
        }

        CheckBox {
            id: italicText

            Kirigami.FormData.label: i18n("Italic text")
        }

        Label {
            Kirigami.FormData.label: i18n("Preview:")
            Layout.fillWidth: true
            font.bold: boldText.checked
            font.italic: italicText.checked
            font.pointSize: fontSize.value
            text: configAppearance.preview(12345.678) + " / " + configAppearance.preview(0.0000123456)
            wrapMode: Text.Wrap
        }

        CheckBox {
            id: advancedFormatting

            text: i18n("Advanced number formatting")
        }

        SpinBox {
            id: largePriceThreshold

            Kirigami.FormData.label: i18n("Large price threshold")
            editable: true
            from: standardPriceThreshold.value
            stepSize: 1
            to: 1e+06
            visible: advancedFormatting.checked
        }

        SpinBox {
            id: largePriceDecimals

            Kirigami.FormData.label: i18n("Large price decimals")
            editable: true
            from: 0
            stepSize: 1
            to: 12
            visible: advancedFormatting.checked
        }

        SpinBox {
            id: standardPriceThreshold

            Kirigami.FormData.label: i18n("Standard price threshold")
            editable: true
            from: 0
            stepSize: 1
            to: 1e+06
            visible: advancedFormatting.checked
        }

        SpinBox {
            id: standardPriceDecimals

            Kirigami.FormData.label: i18n("Standard price decimals")
            editable: true
            from: 0
            stepSize: 1
            to: 12
            visible: advancedFormatting.checked
        }

        SpinBox {
            id: smallPriceSignificantDigits

            Kirigami.FormData.label: i18n("Small price extra digits")
            editable: true
            from: 1
            stepSize: 1
            to: 12
            visible: advancedFormatting.checked
        }

        SpinBox {
            id: minSmallPriceDecimals

            Kirigami.FormData.label: i18n("Small price minimum decimals")
            editable: true
            from: 0
            stepSize: 1
            to: 12
            visible: advancedFormatting.checked
        }

        SpinBox {
            id: maxSmallPriceDecimals

            Kirigami.FormData.label: i18n("Small price maximum decimals")
            editable: true
            from: minSmallPriceDecimals.value
            stepSize: 1
            to: 12
            visible: advancedFormatting.checked
        }
    }
}
