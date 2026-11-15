import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Musictrol

// Главный виджет: стеклянная карточка, живёт на рабочем столе под окнами.
// Шестерёнка переворачивает карточку на обратную сторону — настройки.
Window {
    id: win

    signal searchRequested()
    signal capsuleRequested()
    signal karaokeRequested()

    readonly property int shadowMargin: 40
    readonly property int cardWidth: 380

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint
    color: "transparent"
    title: "Musictrol"
    width: cardWidth + shadowMargin * 2
    height: Math.max(front.implicitHeight, back.implicitHeight) + shadowMargin * 2
    visible: true

    // Цвет обложки плавно перетекает при смене трека.
    property color accent: Music.accentColor
    Behavior on accent { ColorAnimation { duration: 700 } }

    Settings {
        id: prefs
        category: "MainWidget"
        property int posX: -1
        property int posY: -1
        property bool locked: false
        property real glassOpacity: 0.55
    }

    property bool restored: false
    Component.onCompleted: {
        if (prefs.posX >= 0 && prefs.posY >= 0) {
            x = prefs.posX
            y = prefs.posY
        } else {
            x = Screen.virtualX + 40
            y = Screen.virtualY + Screen.desktopAvailableHeight - height - 40
        }
        restored = true
        WindowHelper.setupWidgetWindow(win, WindowHelper.Desktop)
        updateInputRegion()
    }
    onXChanged: if (restored) prefs.posX = x
    onYChanged: if (restored) prefs.posY = y

    // Прозрачные поля вокруг карточки (под тень) не должны перехватывать клики.
    function updateInputRegion() {
        WindowHelper.setInputRect(win, card.x, card.y, card.width, card.height)
    }

    Flipable {
        id: card
        x: win.shadowMargin
        y: win.shadowMargin
        width: win.cardWidth
        height: flipped ? back.implicitHeight : front.implicitHeight
        onHeightChanged: inputTimer.restart()

        property bool flipped: false

        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: card.flipped ? 180 : 0
            Behavior on angle { NumberAnimation { duration: 460; easing.type: Easing.InOutCubic } }
        }

        Timer {
            id: inputTimer
            interval: 340
            onTriggered: win.updateInputRegion()
        }

        // Перетаскивание за пустые места карточки (кнопки клики забирают себе).
        DragHandler {
            target: null
            enabled: !prefs.locked
            onActiveChanged: if (active) WindowHelper.startMove(win)
        }

        // Колесо мыши над карточкой — громкость.
        WheelHandler {
            onWheel: (event) => {
                Music.player.volume = Math.max(0, Math.min(100, Music.player.volume + event.angleDelta.y / 120 * 5))
                volumeToast.show()
            }
        }

        // ── Лицевая сторона: плеер ─────────────────────────────────────────
        front: GlassPane {
            id: front
            window: win
            originX: card.x
            originY: card.y
            width: card.width
            height: card.height
            tintOpacity: prefs.glassOpacity
            accent: win.accent
            implicitHeight: frontColumn.implicitHeight + 40

            ColumnLayout {
                id: frontColumn
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    spacing: 14
                    Layout.fillWidth: true

                    Item {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.lighter(win.accent, 1.2) }
                                GradientStop { position: 1; color: Qt.darker(win.accent, 2.4) }
                            }
                            visible: !cover.ready
                            Icon {
                                anchors.centerIn: parent
                                name: "music"
                                size: 26
                                color: Qt.rgba(1, 1, 1, 0.8)
                                visible: !Music.hasTrack
                            }
                        }
                        RoundedImage {
                            id: cover
                            anchors.fill: parent
                            radius: 12
                            source: Music.currentThumbnail
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            Layout.fillWidth: true
                            text: Music.hasTrack ? Music.currentTitle : "Ничего не играет"
                            color: Theme.fg
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: Music.player.loading ? "Загрузка…"
                                  : Music.hasTrack ? Music.currentArtist : "Найдите трек через поиск"
                            color: Theme.dim
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        iconName: "search"
                        text: "Поиск"
                        iconColor: Theme.dim
                        iconSize: 18
                        Layout.alignment: Qt.AlignTop
                        onClicked: win.searchRequested()
                    }
                    IconButton {
                        iconName: "settings"
                        text: "Настройки"
                        iconColor: Theme.dim
                        iconSize: 18
                        Layout.alignment: Qt.AlignTop
                        Layout.leftMargin: -10
                        onClicked: card.flipped = true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    SeekBar {
                        Layout.fillWidth: true
                        value: Music.player.position
                        to: Music.player.duration
                        accent: win.accent
                        onSeekRequested: (s) => Music.player.seek(s)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: Music.formatTime(Music.player.position); color: Theme.faint; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Label { text: Music.formatTime(Music.player.duration); color: Theme.faint; font.pixelSize: 11 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    IconButton {
                        iconName: "lyrics"
                        text: "Караоке"
                        round: false
                        iconColor: Qt.lighter(win.accent, 1.35)
                        baseColor: Qt.alpha(win.accent, 0.18)
                        onClicked: win.karaokeRequested()
                    }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        iconName: "prev"
                        text: "Предыдущий"
                        iconSize: 20
                        implicitWidth: 44; implicitHeight: 44
                        onClicked: Music.previous()
                    }
                    IconButton {
                        iconName: Music.player.paused || !Music.hasTrack ? "play" : "pause"
                        text: Music.player.paused ? "Играть" : "Пауза"
                        iconSize: 22
                        iconStroke: 2.5
                        iconColor: Theme.dark
                        baseColor: Theme.fg
                        hoverColor: Qt.rgba(1, 1, 1, 0.2)
                        implicitWidth: 54; implicitHeight: 54
                        onClicked: Music.togglePause()
                    }
                    IconButton {
                        iconName: "next"
                        text: "Следующий"
                        iconSize: 20
                        implicitWidth: 44; implicitHeight: 44
                        onClicked: Music.next()
                    }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        iconName: "capsule"
                        text: "Выпустить капсулу"
                        round: false
                        iconColor: Theme.dim
                        baseColor: Qt.rgba(1, 1, 1, 0.08)
                        onClicked: win.capsuleRequested()
                    }
                }
            }

            // Всплывающая громкость при прокрутке колеса.
            Rectangle {
                id: volumeToast
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                width: volRow.implicitWidth + 24
                height: 30
                radius: 15
                color: Qt.rgba(0.05, 0.04, 0.08, 0.85)
                opacity: 0
                visible: opacity > 0

                function show() {
                    opacity = 1
                    hideTimer.restart()
                }
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Timer { id: hideTimer; interval: 900; onTriggered: volumeToast.opacity = 0 }

                Row {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        name: Music.player.volume > 0 ? "volume" : "mute"
                        size: 16
                        color: Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: Math.round(Music.player.volume) + "%"
                        color: Theme.fg
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── Обратная сторона: настройки ───────────────────────────────────
        back: GlassPane {
            id: back
            window: win
            originX: card.x
            originY: card.y
            width: card.width
            height: card.height
            tintOpacity: Math.max(prefs.glassOpacity, 0.7)
            accent: win.accent
            implicitHeight: backColumn.implicitHeight + 36

            ColumnLayout {
                id: backColumn
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    spacing: 6
                    IconButton {
                        iconName: "back"
                        text: "Назад"
                        iconSize: 18
                        onClicked: card.flipped = false
                    }
                    Label {
                        text: "Настройки"
                        color: Theme.fg
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Label { text: "Прозрачность стекла"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                        Label { text: Math.round((1 - prefs.glassOpacity) * 100) + "%"; color: Theme.faint; font.pixelSize: 12 }
                    }
                    Slider {
                        id: glassSlider
                        Layout.fillWidth: true
                        from: 0.85
                        to: 0.2
                        value: prefs.glassOpacity
                        onMoved: prefs.glassOpacity = value
                        background: Rectangle {
                            x: glassSlider.leftPadding
                            y: glassSlider.topPadding + glassSlider.availableHeight / 2 - height / 2
                            width: glassSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.15)
                            Rectangle {
                                width: glassSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: win.accent
                            }
                        }
                        handle: Rectangle {
                            x: glassSlider.leftPadding + glassSlider.visualPosition * (glassSlider.availableWidth - width)
                            y: glassSlider.topPadding + glassSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: "white"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Закрепить на месте"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                    Toggle {
                        checked: prefs.locked
                        accent: win.accent
                        onToggled: prefs.locked = checked
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Запускать вместе с системой"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                    Toggle {
                        checked: AppSettings.autostart
                        accent: win.accent
                        onToggled: AppSettings.autostart = checked
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Горячие клавиши"; color: Theme.faint; font.pixelSize: 14; Layout.fillWidth: true }
                    Label { text: "скоро"; color: Theme.faint; font.pixelSize: 12 }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                AbstractButton {
                    id: quitBtn
                    Layout.fillWidth: true
                    implicitHeight: 40
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    text: "Выйти из Musictrol"
                    onClicked: AppSettings.quit()
                    background: Rectangle {
                        radius: 12
                        color: quitBtn.hovered ? Qt.rgba(1, 0.16, 0.21, 0.22) : Qt.rgba(1, 0.16, 0.21, 0.12)
                    }
                    contentItem: Row {
                        spacing: 8
                        Item { width: (quitBtn.width - 18 - 8 - quitLabel.implicitWidth) / 2 - quitBtn.leftPadding; height: 1 }
                        Icon { name: "power"; size: 18; color: "#ff8a95"; anchors.verticalCenter: parent.verticalCenter }
                        Label { id: quitLabel; text: quitBtn.text; color: "#ff8a95"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
