import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configAppearance

    property alias cfg_fontSize: fontSize.value
    property alias cfg_displayBaseCurrency: displayBaseCurrency.checked
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
            id: displayBaseCurrency

            Kirigami.FormData.label: i18n("Display base currency")
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
