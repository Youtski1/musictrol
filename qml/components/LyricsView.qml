import QtQuick
import QtQuick.Effects
import Musictrol

// Текст песни, который идёт вместе с музыкой: текущая строка крупнее и ярче,
// список плавно прокручивается; клик по строке — перемотка к ней.
// Без таймингов — просто прокручиваемый текст.
Item {
    id: view

    property color accent: Theme.brand
    property int visibleLines: 3
    property int fontSize: 15

    // Пока false — позиция не читается вовсе: никаких пересчётов и перерисовок.
    property bool active: true
    property int frozenLine: -1
    readonly property int current: active ? (Lyrics.synced ? Lyrics.lineAt(Music.player.position) : -1) : frozenLine
    onCurrentChanged: if (active) frozenLine = current
    implicitHeight: Lyrics.status === "found" ? (Lyrics.synced ? visibleLines * (fontSize + 14) : 110) : 30

    Text {
        anchors.centerIn: parent
        visible: Lyrics.status !== "found"
        text: Lyrics.status === "loading" ? "Ищу текст песни…"
              : Lyrics.status === "notfound" ? "Текст песни не найден" : ""
        color: Theme.faint
        font.pixelSize: 12
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: Lyrics.status === "found"
        model: Lyrics.lines
        clip: true
        interactive: !Lyrics.synced
        spacing: 2
        currentIndex: Math.max(0, view.current)
        highlightRangeMode: Lyrics.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - (view.fontSize + 12) / 2
        preferredHighlightEnd: height / 2 + (view.fontSize + 12) / 2
        // Плавная прокрутка к новой строке.
        highlightMoveDuration: 650
        highlightMoveVelocity: -1

        // Мягкое исчезание строк к краям.
        layer.enabled: Lyrics.synced
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
        }

        delegate: Text {
            id: line
            required property int index
            required property var modelData
            readonly property bool active: Lyrics.synced && index === view.current
            // Чем дальше от текущей строки, тем прозрачнее — без скачков шрифта.
            readonly property int distance: Lyrics.synced ? Math.abs(index - view.current) : 0
            width: ListView.view.width
            height: view.fontSize + 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: modelData.text
            // Размер и жирность одинаковые у всех строк (смена шрифта даёт рывок);
            // выделение — плавным масштабом, цветом и прозрачностью.
            font.pixelSize: view.fontSize
            font.weight: Font.DemiBold
            color: active ? "white" : Qt.lighter(view.accent, 1.9)
            opacity: !Lyrics.synced ? 0.75 : active ? 1 : distance === 1 ? 0.45 : 0.22
            scale: active ? 1.12 : 1
            transformOrigin: Item.Center
            Behavior on color { ColorAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { duration: 550; easing.type: Easing.InOutQuad } }
            Behavior on scale { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                enabled: Lyrics.synced && line.modelData.time >= 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Music.player.seek(line.modelData.time)
            }
        }
    }

    Item {
        id: fadeMask
        anchors.fill: list
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: "white" }
                GradientStop { position: 0.7; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
