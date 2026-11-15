import QtQuick
import QtQuick.Controls.Basic
import Musictrol

// Громкость-капсула: в покое только иконка динамика, при наведении плавно
// растягивается в капсулу с ползунком и процентами.
Item {
    id: pill

    property color accent: Theme.brand
    readonly property int collapsedWidth: 36
    // Ширина подобрана под ряд кнопок карточки (340 px): кнопки + капсула помещаются ровно.
    property int expandedWidth: 160

    // Раскрыта, пока над ней мышь, пока тянут ползунок и ещё немного после.
    readonly property bool expanded: hover.hovered || slider.pressed || stayTimer.running

    // Ненадолго раскрыть (например, при прокрутке колеса над карточкой).
    function peek() { stayTimer.restart() }

    implicitWidth: expanded ? expandedWidth : collapsedWidth
    implicitHeight: 36
    Behavior on implicitWidth { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) stayTimer.restart()
    }
    Timer { id: stayTimer; interval: 700 }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, pill.expanded ? 0.10 : 0.06)
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    Item {
        anchors.fill: parent
        clip: true

        IconButton {
            id: muteBtn
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 32
            implicitHeight: 32
            iconName: Music.player.muted || Music.player.volume <= 0 ? "mute" : "volume"
            iconSize: 17
            iconColor: Music.player.muted ? Theme.faint : Theme.fg
            hoverColor: "transparent"
            text: Music.player.muted ? "Включить звук" : "Без звука"
            onClicked: Music.player.muted = !Music.player.muted
        }

        GlassSlider {
            id: slider
            anchors.left: muteBtn.right
            anchors.leftMargin: 4
            anchors.right: percent.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: 100
            value: Music.player.muted ? 0 : Music.player.volume
            smoothing: 90
            accent: pill.accent
            opacity: pill.expanded ? 1 : 0
            enabled: pill.expanded
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            onMoved: (v) => {
                if (Music.player.muted)
                    Music.player.muted = false
                Music.player.volume = v
            }
        }

        Label {
            id: percent
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            horizontalAlignment: Text.AlignRight
            text: Music.player.muted ? "выкл" : Math.round(Music.player.volume) + "%"
            color: Theme.faint
            font.pixelSize: 11
            opacity: pill.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 260 } }
        }
    }
}
