pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.prison as Prison

KCM.SimpleKCM {
    id: configSupport

    readonly property var addresses: [
        {
            name: "Bitcoin",
            address: "bc1pctjprf84cfeljfn3a4d8ptkra8f8smnz9eyvt4j5f84j6dlerwzqrgsq3u"
        },
        {
            name: "Ethereum",
            address: "0xA3322B8FB1342FD8B6796cC9d4cCbCF56CB5D783"
        },
        {
            name: "Solana",
            address: "Cs2d9otY51KkdPqA23xtRyY2vXFA7U3pxKg2oNvGKWNN"
        },
        {
            name: "Quai",
            address: "0x0024826B61a2c3D6C83a5eF3A3D5D31551BB1Fe4"
        }
    ]
    property string copiedName: ""
    property string selectedAddress: ""
    property string selectedName: ""

    TextEdit {
        id: clipboardHelper

        visible: false
    }

    Timer {
        id: feedbackTimer

        interval: 3000

        onTriggered: configSupport.copiedName = ""
    }

    Dialog {
        id: qrDialog

        anchors.centerIn: parent
        modal: true
        objectName: "donationQr"
        parent: Overlay.overlay
        standardButtons: Dialog.Close
        title: configSupport.selectedName
        width: Math.min(Kirigami.Units.gridUnit * 18, configSupport.width)

        contentItem: Prison.Barcode {
            Accessible.name: i18n("%1 donation address QR code", configSupport.selectedName)
            backgroundColor: "white"
            barcodeType: Prison.Barcode.QRCode
            content: configSupport.selectedAddress
            foregroundColor: "black"
            implicitHeight: implicitWidth
            implicitWidth: Kirigami.Units.gridUnit * 14
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Label {
            font.bold: true
            text: i18n("Support Kryptotrack")
        }

        Label {
            Layout.fillWidth: true
            text: i18n("Your support helps maintain and improve this widget.")
            wrapMode: Text.Wrap
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            text: i18n("%1 address copied.", configSupport.copiedName)
            type: Kirigami.MessageType.Positive
            visible: configSupport.copiedName !== ""
        }

        Repeater {
            model: configSupport.addresses

            delegate: ColumnLayout {
                id: addressRow

                required property var modelData

                Layout.fillWidth: true

                Label {
                    font.bold: true
                    text: addressRow.modelData.name
                }

                Label {
                    Accessible.name: addressRow.modelData.name + " " + text
                    Layout.fillWidth: true
                    text: addressRow.modelData.address
                    wrapMode: Text.WrapAnywhere
                }

                RowLayout {
                    Button {
                        Accessible.name: i18n("Copy %1 address", addressRow.modelData.name)
                        icon.name: "edit-copy"
                        objectName: "copyAddress-" + addressRow.modelData.name
                        text: i18n("Copy address")

                        onClicked: {
                            clipboardHelper.text = addressRow.modelData.address;
                            clipboardHelper.selectAll();
                            clipboardHelper.copy();
                            configSupport.copiedName = addressRow.modelData.name;
                            feedbackTimer.restart();
                        }
                    }

                    Button {
                        Accessible.name: i18n("Show %1 QR code", addressRow.modelData.name)
                        icon.name: "view-barcode-qr"
                        text: i18n("Show QR code")

                        onClicked: {
                            configSupport.selectedAddress = addressRow.modelData.address;
                            configSupport.selectedName = addressRow.modelData.name;
                            qrDialog.open();
                        }
                    }
                }
            }
        }
    }
}
