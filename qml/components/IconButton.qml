import QtQuick
import QtQuick.Controls.Basic
import Musictrol

// Круглая (или скруглённая) кнопка с иконкой. text — подпись для доступности и подсказки.
AbstractButton {
    id: btn

    property string iconName
    property real iconSize: 20
    property real iconStroke: 2
    property color iconColor: Theme.fg
    property color baseColor: "transparent"
    property color hoverColor: Theme.hover
    property bool round: true

    implicitWidth: 40
    implicitHeight: 40
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    Accessible.name: text
    ToolTip.visible: hovered && text.length > 0
    ToolTip.delay: 700
    ToolTip.text: text

    scale: down ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    background: Rectangle {
        radius: btn.round ? width / 2 : 12
        color: btn.hovered ? Qt.tint(btn.baseColor, btn.hoverColor) : btn.baseColor
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: btn.iconName
            size: btn.iconSize
            strokeWidth: btn.iconStroke
            color: btn.iconColor
        }
    }
}
