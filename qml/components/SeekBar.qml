import QtQuick
import Musictrol

// Полоса прогресса трека: клик или перетаскивание — перемотка.
Item {
    id: bar

    property real value: 0
    property real to: 0
    property color accent: Theme.brand

    signal seekRequested(real seconds)

    implicitHeight: 16

    readonly property real ratio: to > 0 ? Math.max(0, Math.min(1, value / to)) : 0
    property real dragRatio: 0
    readonly property bool active: area.containsMouse || area.pressed
    readonly property real shownRatio: area.pressed ? dragRatio : ratio

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: bar.active ? 6 : 4
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.15)
        Behavior on height { NumberAnimation { duration: Theme.durFast } }

        Rectangle {
            width: Math.max(height, parent.width * bar.shownRatio)
            height: parent.height
            radius: height / 2
            color: bar.accent
            visible: bar.shownRatio > 0
        }
    }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * bar.shownRatio - width / 2
        opacity: bar.active && bar.to > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        enabled: bar.to > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        function ratioAt(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: (mouse) => bar.dragRatio = ratioAt(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) bar.dragRatio = ratioAt(mouse.x) }
        onReleased: bar.seekRequested(bar.dragRatio * bar.to)
    }
}
