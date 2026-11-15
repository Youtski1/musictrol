import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window
import Musictrol

// Мини-виджет: капсула в левом верхнем углу экрана, поверх всех окон.
// Клик по обложке/названию или ⌄ — открыть панель музыки.
Window {
    id: mini

    property bool panelOpen: false
    signal togglePanel()

    readonly property int margin: 16      // поле под тень
    readonly property int edge: 16        // отступ от угла экрана

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Musictrol mini"
    width: pill.width + margin * 2
    height: pill.height + margin * 2
    x: Screen.virtualX + edge - margin
    y: Screen.virtualY + edge - margin
    visible: true

    property color accent: Music.accentColor
    Behavior on accent { ColorAnimation { duration: 700 } }

    Component.onCompleted: {
        WindowHelper.setupWidgetWindow(mini, WindowHelper.Above)
        updateInput()
    }
    onWidthChanged: Qt.callLater(updateInput)

    function updateInput() {
        WindowHelper.setInputRect(mini, pill.x, pill.y, pill.width, pill.height)
    }

    GlassPane {
        id: pill
        window: mini
        x: mini.margin
        y: mini.margin
        height: 48
        width: row.implicitWidth + 12
        radius: height / 2
        useWallpaper: false
        tintOpacity: 0.86
        shadowBlur: 14
        accent: mini.accent
        borderColor: mini.panelOpen ? Qt.alpha(mini.accent, 0.6) : Theme.glassBorder

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Row {
            id: row
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Обложка + название — клик открывает панель.
            Item {
                width: coverBox.width + titleLabel.width + 12
                height: 38
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    id: coverBox
                    width: 38
                    height: 38
                    Rectangle {
                        anchors.fill: parent
                        radius: 19
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(mini.accent, 1.2) }
                            GradientStop { position: 1; color: Qt.darker(mini.accent, 2.4) }
                        }
                        visible: !miniCover.ready
                        Icon { anchors.centerIn: parent; name: "music"; size: 16; color: Qt.rgba(1, 1, 1, 0.85) }
                    }
                    RoundedImage {
                        id: miniCover
                        anchors.fill: parent
                        radius: 19
                        source: Music.currentThumbnail
                    }
                }

                Label {
                    id: titleLabel
                    x: coverBox.width + 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 170)
                    text: Music.hasTrack ? Music.currentTitle : "Musictrol"
                    color: Theme.fg
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                TapHandler { onTapped: mini.togglePanel() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }

            IconButton {
                iconName: Music.player.paused || !Music.hasTrack ? "play" : "pause"
                text: Music.player.paused ? "Играть" : "Пауза"
                implicitWidth: 34; implicitHeight: 34
                iconSize: 15
                iconStroke: 2.5
                iconColor: Theme.dark
                baseColor: Theme.fg
                hoverColor: Qt.rgba(1, 1, 1, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Music.togglePause()
            }
            IconButton {
                iconName: "next"
                text: "Следующий"
                implicitWidth: 34; implicitHeight: 34
                iconSize: 16
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Music.next()
            }
            IconButton {
                iconName: mini.panelOpen ? "up" : "down"
                text: mini.panelOpen ? "Свернуть" : "Открыть музыку"
                implicitWidth: 34; implicitHeight: 34
                iconSize: 16
                iconColor: mini.panelOpen ? Qt.lighter(mini.accent, 1.35) : Theme.dim
                baseColor: mini.panelOpen ? Qt.alpha(mini.accent, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mini.togglePanel()
            }
        }
    }
}
