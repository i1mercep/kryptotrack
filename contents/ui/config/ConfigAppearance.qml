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
            Kirigami.FormData.label: "Font size"
            from: 4
            to: 72
            stepSize: 1
            onValueChanged: {
                console.log("Font size: " + value);
            }
        }

        CheckBox {
            id: displayBaseCurrency
            Kirigami.FormData.label: "Display base currency"
            onCheckedChanged: {
                console.log("Display base currency: " + checked);
            }
        }
        CheckBox {
            id: boldText
            Kirigami.FormData.label: "Bold text"
            onCheckedChanged: {
                console.log("Bold text: " + checked);
            }
        }
        CheckBox {
            id: italicText
            Kirigami.FormData.label: "Italic text"
            onCheckedChanged: {
                console.log("Italic text: " + checked);
            }
        }
    }
}
