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
    // С запасом: текущая строка может занять два ряда.
    implicitHeight: Lyrics.status === "found" ? (Lyrics.synced ? (visibleLines + 1) * (fontSize + 16) : 110) : 30

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
        // Текущая строка — по центру (строки бывают в 1–2 ряда).
        preferredHighlightBegin: height / 2 - (currentItem ? currentItem.height / 2 : 0)
        preferredHighlightEnd: height / 2 + (currentItem ? currentItem.height / 2 : 0)
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
            // Полная ширина с небольшими полями; строка не увеличивается — за рамку не вылезет.
            width: ListView.view.width - 12
            x: 6
            height: Math.max(view.fontSize + 12, implicitHeight + 6)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            // Длинные строки переносятся (максимум в 2 ряда), а не обрезаются.
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 0.95
            text: modelData.text
            // Размер и жирность одинаковые у всех строк (смена шрифта даёт рывок);
            // выделение — плавным масштабом, цветом и прозрачностью.
            font.pixelSize: view.fontSize
            font.weight: Font.DemiBold
            color: active ? "white" : Qt.lighter(view.accent, 1.9)
            opacity: !Lyrics.synced ? 0.75 : active ? 1 : distance === 1 ? 0.45 : 0.22
            Behavior on color { ColorAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { duration: 550; easing.type: Easing.InOutQuad } }

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
                GradientStop { position: 0.12; color: "white" }
                GradientStop { position: 0.88; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
