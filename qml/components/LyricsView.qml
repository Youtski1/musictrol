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

    readonly property int current: Lyrics.synced ? Lyrics.lineAt(Music.player.position) : -1
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
        highlightMoveDuration: 380

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
            width: ListView.view.width
            height: view.fontSize + 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: modelData.text
            color: active ? "white" : Qt.rgba(1, 1, 1, Lyrics.synced ? 0.38 : 0.7)
            font.pixelSize: active ? view.fontSize + 2 : view.fontSize
            font.weight: active ? Font.Bold : Font.Normal
            style: active ? Text.Raised : Text.Normal
            styleColor: Qt.alpha(view.accent, 0.6)
            Behavior on color { ColorAnimation { duration: 250 } }

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
