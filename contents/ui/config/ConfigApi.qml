import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configApi

    property string cfg_apiProvider: "coingecko"
    property alias cfg_apiKey: apiKey.text
    property alias cfg_timeout: timeout.value

    Kirigami.FormLayout {
        id: formLayout

        anchors.fill: parent

        ComboBox {
            id: apiProvider

            Kirigami.FormData.label: i18n("API Provider")
            model: ["coingecko"]
            displayText: currentText
            Component.onCompleted: {
                currentIndex = model.indexOf(cfg_apiProvider);
            }
            onActivated: {
                cfg_apiProvider = currentText;
            }

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

            Kirigami.FormData.label: i18n("API Key")
            placeholderText: i18n("Enter your CoinGecko Pro API key")
            echoMode: TextInput.Password
        }

        SpinBox {
            id: timeout

            Kirigami.FormData.label: i18n("Timeout (seconds)")
            from: 5
            to: 60
            stepSize: 1
        }

    }

}
