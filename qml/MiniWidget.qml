import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window
import QtCore
import Musictrol

// Капсула (мини-виджет), поверх всех окон.
//  • В покое — кружок с обложкой; пока играет музыка, от него расходятся волны.
//  • Наведение — разворачивается в капсулу: название, пауза, следующий,
//    волны вкл/выкл, поиск (панель музыки), режим перемотки.
//  • Режим перемотки — капсула переезжает вверх по центру и становится волной.
// Окно — прозрачная полоса вдоль верха экрана; клики ловит только сама капсула,
// поэтому переезд — плавная анимация внутри окна, без движения окна.
Window {
    id: mini

    property bool panelOpen: false
    property bool waveMode: false
    signal togglePanel()

    // На каком мониторе жить: имя экрана из настроек, иначе — экран главной карточки.
    property string preferredScreen: ""
    property string followScreen: ""
    readonly property var targetScreen: {
        const list = Qt.application.screens
        const want = preferredScreen.length > 0 ? preferredScreen : followScreen
        for (let i = 0; i < list.length; ++i) {
            if (list[i].name === want)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Musictrol capsule"
    screen: targetScreen
    x: targetScreen ? targetScreen.virtualX : 0
    y: targetScreen ? targetScreen.virtualY : 0
    width: targetScreen ? targetScreen.width : 1280
    height: 150
    visible: true
    onTargetScreenChanged: Qt.callLater(() => WindowHelper.setupWidgetWindow(mini, WindowHelper.Above))

    property color accent: Music.accentColor
    Behavior on accent { ColorAnimation { duration: 700 } }

    Settings {
        id: prefs
        category: "Capsule"
        property bool ripples: true
    }

    // ── Состояние ────────────────────────────────────────────────────────
    property bool hoverHold: false
    readonly property bool expanded: waveMode || panelOpen || hoverHold
    Timer { id: collapseTimer; interval: 700; onTriggered: mini.hoverHold = false }

    readonly property real circleSize: 56
    readonly property real cornerMargin: 16
    readonly property real waveWidth: Math.min(660, width - 80)
    readonly property real waveHeight: 64

    Component.onCompleted: {
        WindowHelper.setupWidgetWindow(mini, WindowHelper.Above)
        updateInput()
    }

    function updateInput() {
        WindowHelper.setInputRect(mini, cap.x, cap.y, cap.width, cap.height)
    }

    function setWaveMode(on) { waveMode = on }

    // Для снимков разработчика: показать развёрнутую капсулу без мыши и волны без музыки.
    function forceExpanded(on) { hoverHold = on }
    property bool previewRipples: Qt.application.arguments.indexOf("--snapshot") > 0

    // ── Волны вокруг кружка ──────────────────────────────────────────────
    Item {
        id: ripples
        readonly property bool active: prefs.ripples && !mini.waveMode
                                       && ((Music.hasTrack && !Music.player.paused) || mini.previewRipples)
        x: cap.x + cover.x + cover.width / 2
        y: cap.y + cover.y + cover.height / 2
        opacity: active ? (mini.expanded ? 0.35 : 1) : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 400 } }

        property real phase: 0
        NumberAnimation on phase {
            from: 0; to: 1
            duration: 2000
            loops: Animation.Infinite
            running: ripples.visible
        }

        Repeater {
            model: 3
            delegate: Item {
                required property int index
                readonly property real p: (ripples.phase + index / 3) % 1
                readonly property real size: cover.width * (1 + 0.75 * p)
                x: -size / 2
                y: -size / 2
                width: size
                height: size
                opacity: Math.pow(1 - p, 1.4)

                // мягкое свечение
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: width / 2
                    color: "transparent"
                    border.width: 7
                    border.color: Qt.alpha(mini.accent, 0.22)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: Qt.lighter(mini.accent, 1.15)
                }
            }
        }
    }

    // ── Капсула ──────────────────────────────────────────────────────────
    GlassPane {
        id: cap
        window: mini
        useWallpaper: false
        tintOpacity: 0.9
        shadowBlur: 16
        accent: mini.accent
        radius: height / 2
        borderColor: (mini.panelOpen || waveArea.dragging) ? Qt.alpha(mini.accent, 0.65) : Theme.glassBorder

        // В покое капсула слегка прозрачная — вписывается в любое окно под ней.
        opacity: (mini.hoverHold || mini.panelOpen || waveArea.dragging) ? 1 : (mini.waveMode ? 0.82 : 0.7)
        Behavior on opacity { NumberAnimation { duration: 300 } }

        readonly property real fullWidth: cover.width + cornerRow.implicitWidth + 22

        x: mini.waveMode ? (mini.width - mini.waveWidth) / 2 : mini.cornerMargin
        y: mini.waveMode ? 18 : mini.cornerMargin
        width: mini.waveMode ? mini.waveWidth : (mini.expanded ? fullWidth : mini.circleSize)
        height: mini.waveMode ? mini.waveHeight : mini.circleSize

        Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }
        Behavior on width { NumberAnimation { duration: 460; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.OutQuint } }

        onXChanged: Qt.callLater(mini.updateInput)
        onYChanged: Qt.callLater(mini.updateInput)
        onWidthChanged: Qt.callLater(mini.updateInput)
        onHeightChanged: Qt.callLater(mini.updateInput)

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop()
                    mini.hoverHold = true
                } else {
                    collapseTimer.restart()
                }
            }
        }

        // Колесо мыши — громкость (в режиме перемотки вместо волны на миг — полоса громкости).
        WheelHandler {
            onWheel: (e) => {
                if (Music.player.muted)
                    Music.player.muted = false
                Music.player.volume = Math.max(0, Math.min(100, Music.player.volume + e.angleDelta.y / 120 * 5))
                volumePeek.restart()
            }
        }
        Timer { id: volumePeek; interval: 1200 }

        Item {
            anchors.fill: parent
            clip: true

            // Обложка-кружок: клик — открыть музыку (в режиме перемотки — пауза).
            Item {
                id: cover
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                width: cap.height - 10
                height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(mini.accent, 1.2) }
                        GradientStop { position: 1; color: Qt.darker(mini.accent, 2.4) }
                    }
                    visible: !coverImg.ready
                    Icon { anchors.centerIn: parent; name: "music"; size: parent.width * 0.4; color: Qt.rgba(1, 1, 1, 0.85) }
                }
                RoundedImage {
                    id: coverImg
                    anchors.fill: parent
                    radius: width / 2
                    source: Music.currentThumbnail
                }
                // Пауза поверх обложки в режиме перемотки
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.45)
                    visible: mini.waveMode && (coverTap.hovered || Music.player.paused)
                    Icon {
                        anchors.centerIn: parent
                        name: Music.player.paused ? "play" : "pause"
                        size: parent.width * 0.38
                        strokeWidth: 2.5
                        color: "white"
                    }
                }
                HoverHandler { id: coverTap; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: mini.waveMode ? Music.togglePause() : mini.togglePanel()
                }
            }

            // Содержимое капсулы в углу
            Row {
                id: cornerRow
                x: cover.x + cover.width + 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                opacity: !mini.waveMode && mini.expanded ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Label {
                    width: Math.min(implicitWidth, 170)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Music.hasTrack ? Music.currentTitle : "Musictrol"
                    color: Theme.fg
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    rightPadding: 6
                }
                IconButton {
                    iconName: Music.player.paused || !Music.hasTrack ? "play" : "pause"
                    text: Music.player.paused ? "Играть" : "Пауза"
                    implicitWidth: 36; implicitHeight: 36
                    iconSize: 14
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
                    implicitWidth: 36; implicitHeight: 36
                    iconSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: Music.next()
                }
                IconButton {
                    iconName: "ripples"
                    text: prefs.ripples ? "Выключить волны" : "Включить волны"
                    implicitWidth: 36; implicitHeight: 36
                    iconSize: 17
                    iconColor: prefs.ripples ? Qt.lighter(mini.accent, 1.35) : Theme.faint
                    baseColor: prefs.ripples ? Qt.alpha(mini.accent, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: prefs.ripples = !prefs.ripples
                }
                IconButton {
                    iconName: "search"
                    text: "Поиск и музыка"
                    implicitWidth: 36; implicitHeight: 36
                    iconSize: 15
                    iconColor: mini.panelOpen ? Qt.lighter(mini.accent, 1.35) : Theme.dim
                    baseColor: mini.panelOpen ? Qt.alpha(mini.accent, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: mini.togglePanel()
                }
                IconButton {
                    iconName: "wave"
                    text: "Режим перемотки"
                    implicitWidth: 36; implicitHeight: 36
                    iconSize: 16
                    iconColor: Theme.dim
                    baseColor: Qt.rgba(1, 1, 1, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: mini.setWaveMode(true)
                }
            }

            // Содержимое в режиме перемотки
            Item {
                id: waveContent
                anchors.left: cover.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                opacity: mini.waveMode ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: mini.waveMode ? 220 : 0 }
                        NumberAnimation { duration: 260 }
                    }
                }

                Row {
                    id: waveButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    IconButton {
                        iconName: "search"
                        text: "Поиск и музыка"
                        implicitWidth: 40; implicitHeight: 40
                        iconSize: 16
                        iconColor: Theme.dim
                        baseColor: Qt.rgba(1, 1, 1, 0.08)
                        onClicked: mini.togglePanel()
                    }
                    IconButton {
                        iconName: "corner"
                        text: "Вернуть в угол"
                        implicitWidth: 40; implicitHeight: 40
                        iconSize: 16
                        iconColor: Qt.lighter(mini.accent, 1.35)
                        baseColor: Qt.alpha(mini.accent, 0.22)
                        onClicked: mini.setWaveMode(false)
                    }
                }

                Label {
                    id: timeLabel
                    anchors.right: waveButtons.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Music.formatTime(Music.player.position) + " / " + Music.formatTime(Music.player.duration)
                    color: Theme.dim
                    font.pixelSize: 12
                }

                WaveSeek {
                    id: waveArea
                    anchors.left: parent.left
                    anchors.right: timeLabel.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    position: Music.player.position
                    duration: Music.player.duration
                    accent: mini.accent
                    seed: Music.currentVideoId
                    playing: Music.hasTrack && !Music.player.paused
                    opacity: volumePeek.running ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    onSeekRequested: (s) => Music.player.seek(s)
                }

                // Громкость на миг вместо волны (при прокрутке колеса)
                Row {
                    anchors.left: parent.left
                    anchors.right: timeLabel.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    opacity: volumePeek.running ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Icon {
                        name: Music.player.volume > 0 ? "volume" : "mute"
                        size: 18
                        color: Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    GlassSlider {
                        width: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 100
                        value: Music.player.volume
                        smoothing: 80
                        accent: mini.accent
                        enabled: false
                    }
                    Label {
                        text: Math.round(Music.player.volume) + "%"
                        color: Theme.dim
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
