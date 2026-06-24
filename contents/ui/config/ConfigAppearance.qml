import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configAppearance

    property alias cfg_fontSize: fontSize.value
    property alias cfg_useThousandsSeparators: useThousandsSeparators.checked
    property alias cfg_largePriceThreshold: largePriceThreshold.value
    property alias cfg_largePriceDecimals: largePriceDecimals.value
    property alias cfg_standardPriceThreshold: standardPriceThreshold.value
    property alias cfg_standardPriceDecimals: standardPriceDecimals.value
    property alias cfg_smallPriceSignificantDigits: smallPriceSignificantDigits.value
    property alias cfg_minSmallPriceDecimals: minSmallPriceDecimals.value
    property alias cfg_maxSmallPriceDecimals: maxSmallPriceDecimals.value
    property alias cfg_displayBaseCurrency: displayBaseCurrency.checked
    property alias cfg_show24hChange: show24hChange.checked
    property alias cfg_boldText: boldText.checked
    property alias cfg_italicText: italicText.checked

    Kirigami.FormLayout {
        id: formLayout

        anchors.fill: parent

        SpinBox {
            id: fontSize

            Kirigami.FormData.label: i18n("Font size")
            from: 4
            to: 72
            stepSize: 1
        }

        CheckBox {
            id: useThousandsSeparators

            Kirigami.FormData.label: i18n("Number formatting")
            text: i18n("Use locale-specific thousands separators")
        }

        SpinBox {
            id: largePriceThreshold

            Kirigami.FormData.label: i18n("Large price threshold")
            from: 0
            to: 1e+06
            stepSize: 1
        }

        SpinBox {
            id: largePriceDecimals

            Kirigami.FormData.label: i18n("Large price decimals")
            from: 0
            to: 12
            stepSize: 1
        }

        SpinBox {
            id: standardPriceThreshold

            Kirigami.FormData.label: i18n("Standard price threshold")
            from: 0
            to: 1e+06
            stepSize: 1
        }

        SpinBox {
            id: standardPriceDecimals

            Kirigami.FormData.label: i18n("Standard price decimals")
            from: 0
            to: 12
            stepSize: 1
        }

        SpinBox {
            id: smallPriceSignificantDigits

            Kirigami.FormData.label: i18n("Small price extra digits")
            from: 1
            to: 12
            stepSize: 1
        }

        SpinBox {
            id: minSmallPriceDecimals

            Kirigami.FormData.label: i18n("Small price minimum decimals")
            from: 0
            to: 12
            stepSize: 1
        }

        SpinBox {
            id: maxSmallPriceDecimals

            Kirigami.FormData.label: i18n("Small price maximum decimals")
            from: 0
            to: 12
            stepSize: 1
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

    }

}
