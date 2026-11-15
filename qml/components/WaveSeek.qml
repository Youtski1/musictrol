import QtQuick
import Musictrol

// Волна-ползунок капсулы: столбики «дышат» в такт, сыгранная часть — цветом
// обложки, белая метка — позиция. Тянешь по волне — перемотка.
// Рисунок волны свой у каждого трека (зависит от videoId).
// Анимация идёт только пока трек играет и волна видна.
Item {
    id: ws

    property real position: 0
    property real duration: 0
    property color accent: Theme.brand
    property string seed: ""
    property bool playing: false

    signal seekRequested(real seconds)

    readonly property int barCount: Math.max(24, Math.floor(width / 7))
    readonly property real barStep: width / barCount
    readonly property real ratio: duration > 0 ? Math.max(0, Math.min(1, position / duration)) : 0
    readonly property bool dragging: area.pressed
    property real dragRatio: 0
    readonly property real headRatio: dragging ? dragRatio : ratio

    // Псевдослучайные, но постоянные для трека высоты и ритм столбиков.
    readonly property var shape: {
        let s = 0
        for (let i = 0; i < seed.length; ++i)
            s = (s * 31 + seed.charCodeAt(i)) % 100000
        const rnd = (i) => { const x = Math.sin((s + i) * 12.9898) * 43758.5453; return x - Math.floor(x) }
        const arr = []
        for (let i = 0; i < barCount; ++i) {
            const env = 0.55 + 0.45 * Math.sin(Math.PI * (i + 0.5) / barCount)
            arr.push({ h: 0.25 + 0.75 * env * (0.35 + 0.65 * rnd(i)), speed: 1 + Math.floor(rnd(i + 500) * 3), phase: rnd(i + 900) * Math.PI * 2 })
        }
        return arr
    }

    // 30 кадров в секунду — плавно и вдвое дешевле, чем 60.
    property real t: 0
    Timer {
        interval: 33
        repeat: true
        running: ws.playing && ws.visible && ws.opacity > 0 && !area.pressed
        onTriggered: ws.t = (ws.t + Math.PI * 2 * 0.033 / 1.8) % (Math.PI * 2)
    }

    Repeater {
        model: ws.barCount
        delegate: Rectangle {
            required property int index
            readonly property var s: ws.shape[index] ?? { h: 0.5, speed: 1, phase: 0 }
            readonly property real centerRatio: (index + 0.5) / ws.barCount
            readonly property real amp: ws.playing && !area.pressed ? 0.55 + 0.45 * Math.sin(ws.t * s.speed + s.phase) : 0.8
            x: index * ws.barStep + 1
            width: Math.max(2, ws.barStep - 2)
            height: Math.max(3, ws.height * s.h * amp)
            y: (ws.height - height) / 2
            radius: width / 2
            color: centerRatio <= ws.ratio ? Qt.lighter(ws.accent, 1.15)
                   : (ws.dragging && centerRatio <= ws.dragRatio) ? Qt.alpha(ws.accent, 0.55)
                   : Qt.rgba(1, 1, 1, 0.22)
        }
    }

    // Метка позиции
    Rectangle {
        x: ws.width * ws.headRatio - 1
        y: -3
        width: 2
        height: ws.height + 6
        radius: 1
        color: "white"
        visible: ws.duration > 0
    }

    // Время над меткой — при наведении и перетаскивании.
    Rectangle {
        readonly property real hoverRatio: area.pressed ? ws.dragRatio : area.mouseX / Math.max(1, ws.width)
        visible: (area.containsMouse || area.pressed) && ws.duration > 0
        width: bubbleText.implicitWidth + 14
        height: 22
        radius: 8
        color: "white"
        y: -height - 6
        x: Math.max(-6, Math.min(ws.width - width + 6, ws.width * hoverRatio - width / 2))
        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: Music.formatTime(parent.hoverRatio * ws.duration)
            color: Theme.dark
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        hoverEnabled: true
        enabled: ws.duration > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        function ratioAt(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: (m) => ws.dragRatio = ratioAt(m.x)
        onPositionChanged: (m) => { if (pressed) ws.dragRatio = ratioAt(m.x) }
        onReleased: ws.seekRequested(ws.dragRatio * ws.duration)
    }
}
