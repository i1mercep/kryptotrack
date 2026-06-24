import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configApi

    property string cfg_apiProvider: "binance"
    property alias cfg_apiKey: apiKey.text
    property alias cfg_timeout: timeout.value
    readonly property bool isCoinGeckoProvider: cfg_apiProvider === "coingecko"
    readonly property string providerDisplayName: cfg_apiProvider === "coingecko" ? "CoinGecko" : "Binance"

    Kirigami.FormLayout {
        id: formLayout

        anchors.fill: parent

        ComboBox {
            id: apiProvider

            Kirigami.FormData.label: i18n("API Provider")
            model: ["binance", "coingecko"]
            displayText: configApi.providerDisplayName
            Component.onCompleted: {
                currentIndex = Math.max(model.indexOf(cfg_apiProvider), 0);
                cfg_apiProvider = currentText;
            }
            onActivated: {
                cfg_apiProvider = currentText;
            }

            delegate: ItemDelegate {
                width: apiProvider.width
                highlighted: apiProvider.highlightedIndex === index

                contentItem: Text {
                    text: modelData === "coingecko" ? "CoinGecko" : "Binance"
                    verticalAlignment: Text.AlignVCenter
                }

            }

        }

        Label {
            visible: !configApi.isCoinGeckoProvider
            text: i18n("Binance uses public Spot market data and does not require an API key.")
            wrapMode: Text.WordWrap
        }

        TextField {
            id: apiKey

            Kirigami.FormData.label: i18n("API Key")
            placeholderText: i18n("Enter your CoinGecko Pro API key")
            echoMode: TextInput.Password
            visible: configApi.isCoinGeckoProvider
            enabled: visible
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
