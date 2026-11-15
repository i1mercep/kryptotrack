pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property string assetText: ""
    property string baseCurrencyText: ""
    property bool boldText: false
    property string changeText: ""
    property double changeValue: 0
    property string description: ""
    readonly property string displayText: assetText + " " + priceText + (baseCurrencyText ? " " + baseCurrencyText : "")
    property bool hasQuote: false
    property bool italicText: false
    property bool loading: false
    property int pointSize: 9
    property string priceText: "—"
    property bool vertical: false
    property string warningText: ""

    Accessible.description: root.description
    Accessible.name: root.displayText
    Accessible.role: Accessible.StaticText
    Layout.minimumHeight: root.vertical ? implicitHeight : Kirigami.Units.gridUnit
    Layout.minimumWidth: root.vertical ? Kirigami.Units.gridUnit * 2 : implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    implicitHeight: content.implicitHeight + Kirigami.Units.smallSpacing * 2
    implicitWidth: content.implicitWidth + Kirigami.Units.smallSpacing * 2

    GridLayout {
        id: content

        anchors.centerIn: parent
        columnSpacing: Kirigami.Units.smallSpacing
        columns: root.vertical ? 1 : 3
        rowSpacing: Kirigami.Units.smallSpacing
        width: root.vertical ? Math.max(0, parent.width - Kirigami.Units.smallSpacing * 2) : implicitWidth

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: root.vertical
            Layout.minimumWidth: 0
            font.bold: root.boldText
            font.italic: root.italicText
            font.pointSize: root.pointSize
            fontSizeMode: root.vertical ? Text.Fit : Text.FixedSize
            horizontalAlignment: Text.AlignHCenter
            minimumPointSize: 4
            objectName: "priceLabel"
            text: root.vertical ? root.assetText + "\n" + root.priceText + (root.baseCurrencyText ? "\n" + root.baseCurrencyText : "") : root.displayText
        }

        PlasmaComponents.Label {
            Accessible.name: i18n("24h change: %1", root.changeText)
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: root.vertical
            Layout.minimumWidth: 0
            color: root.changeValue > 0 ? Kirigami.Theme.positiveTextColor : root.changeValue < 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            font.bold: root.boldText
            font.italic: root.italicText
            font.pointSize: Math.max(4, root.pointSize - 1)
            fontSizeMode: root.vertical ? Text.Fit : Text.FixedSize
            horizontalAlignment: Text.AlignHCenter
            minimumPointSize: 4
            text: root.changeText
            visible: root.changeText !== ""
        }

        PlasmaComponents.BusyIndicator {
            Accessible.name: i18n("Loading price")
            Layout.alignment: Qt.AlignCenter
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            objectName: "loadingIndicator"
            running: visible
            visible: root.loading && !root.hasQuote
        }

        Kirigami.Icon {
            Accessible.name: root.warningText
            Layout.alignment: Qt.AlignCenter
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            objectName: "warningIndicator"
            source: "data-warning"
            visible: root.warningText !== ""
        }
    }
}
