import QtQuick
import QtQuick.Controls.Basic
import Musictrol

// Переключатель в стиле стекла.
AbstractButton {
    id: sw

    property color accent: Theme.brand

    checkable: true
    implicitWidth: 44
    implicitHeight: 26
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    Accessible.role: Accessible.CheckBox

    background: Rectangle {
        radius: height / 2
        color: sw.checked ? sw.accent : Qt.rgba(1, 1, 1, sw.hovered ? 0.22 : 0.16)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    contentItem: Item {
        Rectangle {
            width: 20
            height: 20
            radius: 10
            y: (sw.height - height) / 2
            x: sw.checked ? sw.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: Theme.durMid; easing.type: Easing.OutCubic } }
        }
    }
}
