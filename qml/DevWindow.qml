import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Musictrol

// Шаг 1 — временное окно, чтобы проверить поиск и воспроизведение.
// Настоящие виджеты (карточка, капсула, мини-виджет, караоке) придут следующими шагами.
ApplicationWindow {
    id: win
    width: 560
    height: 720
    title: "Musictrol — поиск (временное окно)"
    color: "#0d0b12"

    readonly property color fg: "#f4f1fb"
    readonly property color dim: "#a79fbe"
    readonly property color accent: "#ff2a36"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Поиск
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: query
                Layout.fillWidth: true
                placeholderText: "Поиск на YouTube или ссылка"
                color: win.fg
                placeholderTextColor: win.dim
                font.pixelSize: 15
                background: Rectangle { radius: 12; color: "#1c1826" }
                leftPadding: 14
                onAccepted: Music.search(text)
            }
            Button {
                text: Music.searching ? "…" : "Найти"
                enabled: !Music.searching
                onClicked: Music.search(query.text)
            }
        }

        Label {
            visible: Music.errorText.length > 0
            text: Music.errorText
            color: "#ff8a95"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        // Результаты
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: Music.results

            BusyIndicator {
                anchors.centerIn: parent
                running: Music.searching
            }

            delegate: ItemDelegate {
                id: row
                required property int index
                required property string title
                required property string artist
                required property string thumbnail
                required property real duration

                width: ListView.view.width
                height: 64
                onClicked: Music.playResult(index)

                readonly property bool isCurrent: Music.currentIndex === index && Music.hasTrack

                background: Rectangle {
                    radius: 10
                    color: row.isCurrent ? "#2a1820" : (row.hovered ? "#1a1722" : "transparent")
                }

                contentItem: RowLayout {
                    spacing: 12
                    Image {
                        source: row.thumbnail
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 45
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(160, 90)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: row.title
                            color: row.isCurrent ? win.accent : win.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            font.pixelSize: 14
                            font.bold: row.isCurrent
                        }
                        Label {
                            text: row.artist
                            color: win.dim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            font.pixelSize: 12
                        }
                    }
                    Label {
                        text: Music.formatTime(row.duration)
                        color: win.dim
                        font.pixelSize: 12
                    }
                    Button {
                        text: "+"
                        flat: true
                        ToolTip.visible: hovered
                        ToolTip.text: "В очередь"
                        onClicked: Music.enqueueResult(row.index)
                    }
                }
            }
        }

        // Сейчас играет
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            radius: 18
            color: "#17131f"
            border.color: "#2a2433"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    spacing: 12
                    Image {
                        source: Music.currentThumbnail
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(112, 112)
                        visible: Music.hasTrack
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: Music.hasTrack ? Music.currentTitle : "Ничего не играет"
                            color: win.fg
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: Music.player.loading ? "Загрузка…" : Music.currentArtist
                            color: win.dim
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                RowLayout {
                    spacing: 8
                    Label { text: Music.formatTime(Music.player.position); color: win.dim; font.pixelSize: 12 }
                    Slider {
                        id: seek
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, Music.player.duration)
                        enabled: Music.hasTrack && Music.player.duration > 0
                        onMoved: Music.player.seek(value)
                        Binding on value {
                            value: Music.player.position
                            when: !seek.pressed
                        }
                    }
                    Label { text: Music.formatTime(Music.player.duration); color: win.dim; font.pixelSize: 12 }
                }

                RowLayout {
                    spacing: 8
                    Button { text: "⏮"; onClicked: Music.previous() }
                    Button {
                        text: Music.player.paused ? "▶" : "⏸"
                        enabled: Music.hasTrack
                        onClicked: Music.togglePause()
                    }
                    Button { text: "⏭"; onClicked: Music.next() }
                    Item { Layout.fillWidth: true }
                    Label { text: "Громкость"; color: win.dim; font.pixelSize: 12 }
                    Slider {
                        id: vol
                        Layout.preferredWidth: 140
                        from: 0
                        to: 100
                        onMoved: Music.player.volume = value
                        Binding on value {
                            value: Music.player.volume
                            when: !vol.pressed
                        }
                    }
                }
            }
        }
    }
}
