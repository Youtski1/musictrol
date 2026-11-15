import QtQuick
import QtQuick.Effects
import Musictrol

// Общий ползунок виджетов: перемотка, громкость, настройки.
// Спокойный вид: тонкая полоса, мягкий градиент цветом обложки с лёгким
// свечением, небольшой бегунок. Заливка движется непрерывно, без ступенек.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property color accent: Theme.brand
    // Сглаживание движения заливки между обновлениями значения (мс).
    property int smoothing: 160
    // Подсказка над курсором: функция(значение) → текст. Пусто — без подсказки.
    property var tooltipText: null

    readonly property alias pressed: area.pressed
    readonly property alias hovered: area.containsMouse

    signal moved(real value)      // во время перетаскивания
    signal committed(real value)  // отпустили кнопку мыши

    implicitHeight: 16

    readonly property real span: to - from
    readonly property real ratio: span !== 0 ? Math.max(0, Math.min(1, (value - from) / span)) : 0
    readonly property bool hot: area.containsMouse || area.pressed
    property real dragRatio: 0

    // После отпускания держим бегунок на месте, пока значение (например, позиция
    // плеера после перемотки) не догонит его, — без «отскока» назад.
    property bool holding: false
    Timer { id: holdTimer; interval: 800; onTriggered: root.holding = false }
    onRatioChanged: if (holding && Math.abs(ratio - dragRatio) < 0.02) holding = false

    property real smoothRatio: ratio
    Behavior on smoothRatio {
        enabled: !area.pressed && !root.holding && root.smoothing > 0
        NumberAnimation { duration: root.smoothing; easing.type: Easing.Linear }
    }
    readonly property real shown: (area.pressed || holding) ? dragRatio : smoothRatio

    Item {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.hot ? 5 : 4
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        RectangularShadow {
            anchors.fill: fill
            radius: fill.radius
            blur: 8
            color: Qt.alpha(root.accent, root.hot ? 0.45 : 0.3)
            visible: fill.visible
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(height, parent.width * root.shown)
            radius: height / 2
            visible: root.shown > 0.001
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(root.accent, 0.75) }
                GradientStop { position: 1; color: Qt.lighter(root.accent, 1.2) }
            }
        }
    }

    // Небольшой бегунок, мягко проявляется при наведении.
    Rectangle {
        id: knob
        width: 12
        height: 12
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * root.shown - width / 2
        color: "white"
        border.width: 2
        border.color: Qt.lighter(root.accent, 1.15)
        opacity: root.hot && root.enabled ? 1 : 0
        scale: area.pressed ? 1.15 : (root.hot ? 1 : 0.7)
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    // Подсказка значения над курсором.
    Rectangle {
        id: bubble
        opacity: root.tooltipText !== null && area.containsMouse ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
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
