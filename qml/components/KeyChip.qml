import QtQuick
import QtQuick.Controls.Basic
import Musictrol

// «Фишка» с сочетанием клавиш. Клик — ждёт новое сочетание:
// нажмите клавиши; Backspace — убрать; Esc — отмена.
AbstractButton {
    id: chip

    required property string actionId
    property string sequence: ""
    property string status: ""
    property color accent: Theme.brand
    property bool capturing: false

    signal captureStarted()

    implicitWidth: Math.max(96, label.implicitWidth + 24)
    implicitHeight: 30
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    function stop() {
        if (!capturing)
            return
        capturing = false
        GlobalHotkeys.suspend(false)
    }

    onClicked: {
        capturing = true
        GlobalHotkeys.suspend(true)   // чтобы старые сочетания не срабатывали, пока вводим новое
        captureStarted()
        forceActiveFocus()
    }
    onActiveFocusChanged: if (!activeFocus) stop()

    Keys.onPressed: (event) => {
        if (!capturing)
            return
        event.accepted = true
        if (event.key === Qt.Key_Escape) {
            stop()
        } else if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
            GlobalHotkeys.clear(actionId)
            stop()
        } else if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].indexOf(event.key) < 0) {
            GlobalHotkeys.assign(actionId, event.key, event.modifiers)
            stop()
        }
    }

    ToolTip.visible: hovered && status === "busy" && !capturing
    ToolTip.text: "Это сочетание уже занято другой программой — выберите другое"

    background: Rectangle {
        radius: height / 2
        color: chip.capturing ? Qt.alpha(chip.accent, 0.25)
               : chip.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
        border.width: chip.capturing || chip.status === "busy" ? 1 : 0
        border.color: chip.status === "busy" && !chip.capturing ? "#ff6b78" : Qt.alpha(chip.accent, 0.8)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    contentItem: Item {
        Text {
            id: label
            anchors.centerIn: parent
            text: chip.capturing ? "Нажмите клавиши…"
                  : chip.sequence.length > 0 ? chip.sequence : "не задано"
            color: chip.capturing ? "white"
                   : chip.status === "busy" ? "#ff8a95"
                   : chip.sequence.length > 0 ? Theme.fg : Theme.faint
            font.pixelSize: 12
            font.weight: chip.sequence.length > 0 ? Font.DemiBold : Font.Normal
        }
    }
}
