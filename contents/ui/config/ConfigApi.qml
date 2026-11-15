import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configApi

    property alias cfg_apiKey: apiKey.text
    property string cfg_apiProvider: "binance"
    property alias cfg_timeout: timeout.value

    Kirigami.FormLayout {
        ComboBox {
            id: apiProvider

            Kirigami.FormData.label: i18n("Price provider:")
            currentIndex: configApi.cfg_apiProvider === "coingecko" ? 1 : 0
            model: ["Binance", "CoinGecko"]

            onActivated: configApi.cfg_apiProvider = currentIndex === 1 ? "coingecko" : "binance"
        }

        Label {
            Layout.fillWidth: true
            text: configApi.cfg_apiProvider === "binance" ? i18n("Binance uses public Spot prices. Unsupported pairs use CoinGecko when an exact coin can be identified.") : i18n("CoinGecko provides prices in a range of fiat and cryptocurrency currencies.")
            wrapMode: Text.Wrap
        }

        TextField {
            id: apiKey

            Kirigami.FormData.label: i18n("CoinGecko Pro API key:")
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: i18n("Optional")
        }

        Label {
            Layout.fillWidth: true
            text: i18n("Used for CoinGecko requests, including Binance fallback. Leave empty to use the public service.")
            wrapMode: Text.Wrap
        }

        SpinBox {
            id: timeout

            Kirigami.FormData.label: i18n("Request timeout (seconds):")
            editable: true
            from: 5
            to: 60
        }
    }
}
