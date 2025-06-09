import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configApi

    property alias cfg_apiProvider: apiProvider.currentText
    property alias cfg_apiKey: apiKey.text
    property alias cfg_timeout: timeout.value

    Kirigami.FormLayout {
        id: formLayout
        anchors.fill: parent

        ComboBox {
            id: apiProvider
            Kirigami.FormData.label: "API Provider"
            model: ["coingecko"]
            onActivated: {
                console.log("Selected API provider: " + currentText);
            }
            displayText: currentText
            delegate: ItemDelegate {
                width: apiProvider.width
                highlighted: apiProvider.highlightedIndex === index
                contentItem: Text {
                    text: modelData
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        TextField {
            id: apiKey
            Kirigami.FormData.label: "API Key"
            text: currentText
            placeholderText: "Enter your API key"
            onTextChanged: {
                console.log("API Key: " + text);
            }
        }

        SpinBox {
            id: timeout
            Kirigami.FormData.label: "Timeout (seconds)"
            value: hiddenItems.refreshInterval
            from: 5
            to: 60
            stepSize: 1
            onValueModified: {
                console.log("Set timeout " + value + " seconds")
            }
        }
    }
}