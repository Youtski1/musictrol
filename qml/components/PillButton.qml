import QtQuick
import QtQuick.Controls.Basic
import Musictrol

// Кнопка-«таблетка» с текстом: «Играть», «В очередь», «В плейлист».
AbstractButton {
    id: btn

    property bool primary: false

    implicitWidth: label.implicitWidth + 36
    implicitHeight: 40
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    Accessible.name: text

    scale: down ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    background: Rectangle {
        radius: height / 2
        color: btn.primary ? (btn.hovered ? "white" : Theme.fg)
                           : Qt.rgba(1, 1, 1, btn.hovered ? 0.16 : 0.10)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    contentItem: Item {
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? Theme.dark : Theme.fg
            font.pixelSize: 14
            font.weight: btn.primary ? Font.Bold : Font.Normal
        }
    }
}
