import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configSupport

    // property string btcAddress: "bc1q8zm9lhrz0clrl30nx3n6fhsrytlqgm5yvmj7n9" // segwit
    property string btcAddress: "bc1pctjprf84cfeljfn3a4d8ptkra8f8smnz9eyvt4j5f84j6dlerwzqrgsq3u" // taproot
    property string ethAddress: "0xA3322B8FB1342FD8B6796cC9d4cCbCF56CB5D783" // 0x7772b59C7E4AE00E088EfDa6ED69D22c4a7C43DF
    property string solAddress: "Cs2d9otY51KkdPqA23xtRyY2vXFA7U3pxKg2oNvGKWNN"
    property string quaiAddress: "0x0024826B61a2c3D6C83a5eF3A3D5D31551BB1Fe4"

    Kirigami.ScrollablePage {
        title: i18n("Support This Project")
        anchors.fill: parent

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            anchors.margins: Kirigami.Units.smallSpacing
            anchors.fill: parent

            Label {
                text: "🚀 Love this project? Help it thrive!"
                font.family: Qt.fontFamilies().indexOf("Noto Color Emoji") !== -1 ? "Noto Color Emoji" : "Arial"
                font.bold: true
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                padding: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignHCenter // Center horizontally
            }
            Label {
                text: "Your support lets me improve and maintain this app.\nEvery little bit counts! 💖"
                font.family: Qt.fontFamilies().indexOf("Noto Color Emoji") !== -1 ? "Noto Color Emoji" : "Arial"
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                padding: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignHCenter // Center horizontally
            }

            ListModel {
                id: addressModel
            }

            Component.onCompleted: {
                addressModel.append({ name: "₿ Bitcoin", address: btcAddress });
                addressModel.append({ name: "Ξ Ethereum", address: ethAddress });
                addressModel.append({ name: "◎ Solana", address: solAddress });
                addressModel.append({ name: "  Quai", address: quaiAddress });
            }

            // Hidden TextEdit for clipboard operations
            TextEdit {
                id: clipboardHelper
                visible: false
            }

            Repeater {
                model: addressModel

                delegate: ColumnLayout {
                    spacing: Kirigami.Units.largeSpacing
                    width: parent.width
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Label {
                            text: model.name
                            font.bold: true
                        }
                        Label {
                            text: model.address
                            elide: Text.ElideMiddle
                            wrapMode: Text.Wrap
                            color: Kirigami.Theme.linkColor
                            font.underline: true
                            MouseArea {
                                id: addressArea
                                anchors.fill: parent
                                onClicked: qrDialog.open()
                            }
                        }
                        Button {
                            icon.name: "edit-copy"
                            onClicked: {
                                clipboardHelper.text = model.address
                                clipboardHelper.selectAll()
                                clipboardHelper.copy()
                            }
                        }
                    }
                    

                    Dialog {
                        id: qrDialog
                        modal: true
                        width: 300
                        height: 300
                        standardButtons: Dialog.Close

                        Image {
                            source: "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=" + model.address
                            anchors.centerIn: parent
                            width: parent.width * 0.8
                            height: parent.height * 0.8
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }
        }
    }
}