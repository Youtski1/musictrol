import QtQuick
import QtQuick.Effects
import Musictrol

// Общий ползунок виджетов: перемотка, громкость, настройки.
// Градиентная заливка цветом обложки с мягким свечением, бегунок с кольцом,
// плавное движение заливки и подсказка значения при наведении.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property color accent: Theme.brand
    // Сглаживание движения заливки между редкими обновлениями значения (мс).
    property int smoothing: 120
    // Подсказка над курсором: функция(значение) → текст. Пусто — без подсказки.
    property var tooltipText: null

    signal moved(real value)      // во время перетаскивания
    signal committed(real value)  // отпустили кнопку мыши

    implicitHeight: 18

    readonly property real span: to - from
    readonly property real ratio: span !== 0 ? Math.max(0, Math.min(1, (value - from) / span)) : 0
    readonly property bool hot: area.containsMouse || area.pressed
    property real dragRatio: 0

    // После отпускания держим бегунок на месте, пока значение (например, позиция
    // плеера после перемотки) не догонит его, — без «отскока» назад.
    property bool holding: false
    Timer { id: holdTimer; interval: 800; onTriggered: root.holding = false }
    onRatioChanged: if (holding && Math.abs(ratio - dragRatio) < 0.02) holding = false

    // Плавно догоняет настоящее значение, при перетаскивании — сразу под мышью.
    property real smoothRatio: ratio
    Behavior on smoothRatio {
        enabled: !area.pressed && !root.holding
        NumberAnimation { duration: root.smoothing; easing.type: Easing.Linear }
    }
    readonly property real shown: (area.pressed || holding) ? dragRatio : smoothRatio

    Item {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.hot ? 7 : 5
        Behavior on height { NumberAnimation { duration: Theme.durMid; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)
        }

        RectangularShadow {
            anchors.fill: fill
            radius: fill.radius
            blur: root.hot ? 14 : 9
            color: Qt.alpha(root.accent, root.hot ? 0.75 : 0.5)
            visible: fill.visible
            Behavior on blur { NumberAnimation { duration: Theme.durMid } }
        }

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(height, parent.width * root.shown)
            radius: height / 2
            visible: root.shown > 0.001
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(root.accent, 1.15) }
                GradientStop { position: 1; color: Qt.lighter(root.accent, 1.35) }
            }
        }
    }

    // Бегунок: белый с цветным кольцом, появляется при наведении.
    Rectangle {
        id: knob
        readonly property real size: area.pressed ? 18 : 15
        width: size
        height: size
        radius: size / 2
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * root.shown - width / 2
        color: "white"
        border.width: 3
        border.color: Qt.lighter(root.accent, 1.2)
        opacity: root.hot && root.enabled ? 1 : 0
        scale: root.hot ? 1 : 0.6
        Behavior on opacity { NumberAnimation { duration: Theme.durMid } }
        Behavior on scale { NumberAnimation { duration: Theme.durMid; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: Theme.durFast } }
    }

    // Подсказка значения над курсором.
    Rectangle {
        id: bubble
        visible: root.tooltipText !== null && area.containsMouse
        readonly property real hoverRatio: area.pressed ? root.dragRatio : area.mouseX / Math.max(1, area.width)
        width: bubbleText.implicitWidth + 14
        height: 22
        radius: 11
        color: Qt.rgba(0.06, 0.05, 0.09, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        y: -height - 6
        x: Math.max(-6, Math.min(root.width - width + 6, root.width * hoverRatio - width / 2))

        Text {
            id: bubbleText
            anchors.centerIn: parent
            color: Theme.fg
            font.pixelSize: 11
            text: root.tooltipText ? root.tooltipText(root.from + bubble.hoverRatio * root.span) : ""
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        enabled: root.enabled && root.span !== 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true

        function ratioAt(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: (mouse) => {
            root.dragRatio = ratioAt(mouse.x)
            root.moved(root.from + root.dragRatio * root.span)
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            root.dragRatio = ratioAt(mouse.x)
            root.moved(root.from + root.dragRatio * root.span)
        }
        onReleased: {
            root.holding = true
            holdTimer.restart()
            root.committed(root.from + root.dragRatio * root.span)
        }
    }
}
