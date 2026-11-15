import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Musictrol

// Главный виджет: стеклянная карточка, живёт на рабочем столе под окнами.
// Настройки раскрываются кругом из кнопки-шестерёнки поверх плеера.
// Стекло одно и неподвижное — анимируется только содержимое.
Window {
    id: win

    signal searchRequested()
    signal capsuleRequested()
    signal karaokeRequested()
    signal downloadsRequested()   // клик по обложке — скачанная музыка
    // Поведение капсулы в играх: "hud" | "hide" | "normal".
    property string gameBehavior: "hud"
    signal gameBehaviorChosen(string behavior)
    property bool capsuleEnabled: true
    signal capsuleEnabledChosen(bool enabled)

    readonly property int shadowMargin: 40
    readonly property int cardWidth: 380

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint
    color: "transparent"
    title: "Musictrol"
    // Размер окна постоянный (по большей из сторон) — во время анимаций окно не меняется.
    width: cardWidth + shadowMargin * 2
    height: Math.max(playerColumn.implicitHeight + 40, settingsColumn.implicitHeight + 36,
                     hotkeysColumn.implicitHeight + 36) + shadowMargin * 2
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

    function peekVolume() { volume.peek() }
    function showHotkeysPage(on) { card.showHotkeys = on }

    function setSettingsOpen(open) {
        if (open)
            card.revealOrigin = gearBtn.mapToItem(card, gearBtn.width / 2, gearBtn.height / 2)
        card.showSettings = open
    }

    GlassPane {
        id: card
        window: win
        x: win.shadowMargin
        y: win.shadowMargin
        originX: x
        originY: y
        width: win.cardWidth
        height: showSettings ? (showHotkeys ? hotkeysColumn.implicitHeight + 36 : settingsColumn.implicitHeight + 36)
                             : playerColumn.implicitHeight + 40
        tintOpacity: prefs.glassOpacity
        accent: win.accent

        property bool showSettings: false
        property bool showHotkeys: false
        onShowSettingsChanged: if (!showSettings) showHotkeys = false
        // Точка, откуда растёт круг настроек (центр шестерёнки).
        property point revealOrigin: Qt.point(width - 40, 36)

        Behavior on height { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }
        onHeightChanged: inputTimer.restart()

        Timer {
            id: inputTimer
            interval: 540
            onTriggered: win.updateInputRegion()
        }

        // Перетаскивание за пустые места карточки (кнопки клики забирают себе).
        DragHandler {
            target: null
            enabled: !prefs.locked
            onActiveChanged: if (active) WindowHelper.startMove(win)
        }

        // Колесо мыши над карточкой — громкость (капсула громкости раскрывается).
        WheelHandler {
            enabled: !card.showSettings
            onWheel: (event) => {
                if (Music.player.muted)
                    Music.player.muted = false
                Music.player.volume = Math.max(0, Math.min(100, Music.player.volume + event.angleDelta.y / 120 * 5))
                volume.peek()
            }
        }

        // ── Плеер ─────────────────────────────────────────────────────────
        Item {
            id: playerLayer
            anchors.fill: parent
            opacity: card.showSettings ? 0 : 1
            scale: card.showSettings ? 0.97 : 1
            visible: opacity > 0.01
            enabled: !card.showSettings
            Behavior on opacity { NumberAnimation { duration: 460; easing.type: Easing.InOutCubic } }
            Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }

            ColumnLayout {
                id: playerColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 12

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
                        TapHandler { onTapped: win.downloadsRequested() }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
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

                    // Маленькие кнопки сверху справа: поиск, булавка, настройки.
                    Row {
                        Layout.alignment: Qt.AlignTop
                        spacing: 0
                        IconButton {
                            iconName: "search"
                            text: "Поиск"
                            implicitWidth: 30; implicitHeight: 32
                            iconSize: 16
                            iconColor: Theme.faint
                            onClicked: win.searchRequested()
                        }
                        IconButton {
                            iconName: "wave"
                            text: "Выпустить капсулу (перемотка сверху)"
                            implicitWidth: 30; implicitHeight: 32
                            iconSize: 16
                            iconColor: Theme.faint
                            onClicked: win.capsuleRequested()
                        }
                        IconButton {
                            iconName: "pin"
                            text: prefs.locked ? "Открепить" : "Закрепить на месте"
                            implicitWidth: 30; implicitHeight: 32
                            iconSize: 16
                            iconColor: prefs.locked ? Qt.lighter(win.accent, 1.35) : Theme.faint
                            baseColor: prefs.locked ? Qt.alpha(win.accent, 0.2) : "transparent"
                            onClicked: prefs.locked = !prefs.locked
                        }
                        IconButton {
                            id: gearBtn
                            iconName: "settings"
                            text: "Настройки"
                            implicitWidth: 30; implicitHeight: 32
                            iconSize: 16
                            iconColor: Theme.faint
                            onClicked: {
                                card.revealOrigin = gearBtn.mapToItem(card, width / 2, height / 2)
                                card.showSettings = true
                            }
                        }
                    }
                }

                // Перемотка
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 2
                    GlassSlider {
                        Layout.fillWidth: true
                        value: Music.player.position
                        to: Music.player.duration
                        accent: win.accent
                        tooltipText: (v) => Music.formatTime(v)
                        smoothing: 0   // без постоянной анимации — карточка перерисовывается только при сдвиге
                        onCommitted: (v) => Music.player.seek(v)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: Music.formatTime(Music.player.position); color: Theme.faint; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Label { text: Music.formatTime(Music.player.duration); color: Theme.faint; font.pixelSize: 11 }
                    }
                }

                // Управление + громкость-капсула
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Пока раскрыта громкость, кнопка караоке схлопывается и отдаёт ей место.
                    IconButton {
                        id: karaokeBtn
                        iconName: "lyrics"
                        text: "Караоке"
                        round: false
                        iconColor: Qt.lighter(win.accent, 1.35)
                        baseColor: Qt.alpha(win.accent, 0.18)
                        onClicked: win.karaokeRequested()
                        Layout.preferredWidth: volume.expanded ? 0 : 40
                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
                        opacity: volume.expanded ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        visible: Layout.preferredWidth > 1
                        clip: true
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
                    VolumePill {
                        id: volume
                        accent: win.accent
                    }
                }
            }
        }

        // ── Настройки: раскрываются кругом из шестерёнки ─────────────────
        readonly property real revealMax: {
            const o = revealOrigin
            const h = Math.max(height, settingsColumn.implicitHeight + 36, hotkeysColumn.implicitHeight + 36)
            return Math.hypot(Math.max(o.x, width - o.x), Math.max(o.y, h - o.y)) + 2
        }
        property real revealRadius: showSettings ? revealMax : 0
        Behavior on revealRadius { NumberAnimation { duration: 560; easing.type: Easing.InOutCubic } }
        readonly property bool revealing: revealRadius > 0.5 && revealRadius < revealMax - 0.5

        Item {
            id: settingsLayer
            anchors.fill: parent
            visible: card.revealRadius > 0.5
            enabled: card.showSettings
            // Маска нужна только пока круг растёт/сжимается.
            layer.enabled: card.revealing
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: revealMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusCard
                color: Qt.rgba(0.06, 0.045, 0.1, 0.62)
            }

            ColumnLayout {
                id: settingsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 14
                // Уезжает влево, когда открыта страница горячих клавиш.
                opacity: card.showHotkeys ? 0 : 1
                visible: opacity > 0.01
                enabled: !card.showHotkeys
                transform: Translate {
                    x: card.showHotkeys ? -40 : 0
                    Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 260 } }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Настройки"
                        color: Theme.fg
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                    }
                    // Кнопка закрытия стоит на месте шестерёнки — круг сворачивается туда же.
                    IconButton {
                        iconName: "close"
                        text: "Закрыть настройки"
                        implicitWidth: 32; implicitHeight: 32
                        iconSize: 16
                        iconColor: Theme.dim
                        Layout.rightMargin: -2
                        onClicked: card.showSettings = false
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    RowLayout {
                        Label { text: "Прозрачность стекла"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                        Label { text: Math.round((1 - prefs.glassOpacity) * 100) + "%"; color: Theme.faint; font.pixelSize: 12 }
                    }
                    GlassSlider {
                        Layout.fillWidth: true
                        from: 0.15
                        to: 0.8
                        value: 1 - prefs.glassOpacity
                        smoothing: 0
                        accent: win.accent
                        onMoved: (v) => prefs.glassOpacity = 1 - v
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
                    Label { text: "Капсула в углу"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                    Toggle {
                        checked: win.capsuleEnabled
                        accent: win.accent
                        onToggled: win.capsuleEnabledChosen(checked)
                    }
                }

                // Капсула в играх (полноэкранных программах): клик перебирает варианты.
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Капсула в играх"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                    PillButton {
                        implicitHeight: 30
                        readonly property var order: ["hud", "hide", "normal"]
                        readonly property var names: ({ "hud": "HUD сквозь клики", "hide": "Прятать", "normal": "Как обычно" })
                        text: names[win.gameBehavior] ?? "HUD сквозь клики"
                        onClicked: win.gameBehaviorChosen(order[(order.indexOf(win.gameBehavior) + 1) % order.length])
                    }
                }

                AbstractButton {
                    id: hotkeysEntry
                    Layout.fillWidth: true
                    implicitHeight: 36
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    onClicked: card.showHotkeys = true
                    background: Rectangle {
                        radius: 10
                        color: hotkeysEntry.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    }
                    contentItem: RowLayout {
                        Label { text: "Горячие клавиши"; color: Theme.fg; font.pixelSize: 14; Layout.fillWidth: true }
                        Label {
                            text: {
                                const a = GlobalHotkeys.actions
                                const n = a.filter(x => x.sequence.length > 0).length
                                return n > 0 ? n + " назначено" : "не заданы"
                            }
                            color: Theme.faint
                            font.pixelSize: 12
                        }
                        Icon { name: "back"; size: 14; color: Theme.faint; rotation: 180 }
                    }
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
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: "power"; size: 18; color: "#ff8a95"; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: quitBtn.text; color: "#ff8a95"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // ── Горячие клавиши (подстраница настроек) ───────────────────
            ColumnLayout {
                id: hotkeysColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 8
                opacity: card.showHotkeys ? 1 : 0
                visible: opacity > 0.01
                enabled: card.showHotkeys
                transform: Translate {
                    x: card.showHotkeys ? 0 : 40
                    Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 260 } }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    IconButton {
                        iconName: "back"
                        text: "Назад к настройкам"
                        implicitWidth: 32; implicitHeight: 32
                        iconSize: 16
                        iconColor: Theme.dim
                        Layout.leftMargin: -4
                        onClicked: card.showHotkeys = false
                    }
                    Label {
                        text: "Горячие клавиши"
                        color: Theme.fg
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    IconButton {
                        iconName: "close"
                        text: "Закрыть настройки"
                        implicitWidth: 32; implicitHeight: 32
                        iconSize: 16
                        iconColor: Theme.dim
                        Layout.rightMargin: -2
                        onClicked: card.showSettings = false
                    }
                }

                Repeater {
                    model: GlobalHotkeys.actions
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Label {
                            text: modelData.title
                            color: Theme.fg
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        KeyChip {
                            actionId: modelData.id
                            sequence: modelData.sequence
                            status: modelData.status
                            accent: win.accent
                            onCaptureStarted: win.requestActivate()
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: "Нажмите на сочетание и введите новое. Backspace — убрать, Esc — отмена. Работают из любой программы."
                    color: Theme.faint
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }

        // Круг-маска для раскрытия настроек.
        Item {
            id: revealMask
            anchors.fill: settingsLayer
            layer.enabled: card.revealing
            visible: false
            Rectangle {
                x: card.revealOrigin.x - card.revealRadius
                y: card.revealOrigin.y - card.revealRadius
                width: card.revealRadius * 2
                height: width
                radius: width / 2
            }
        }
    }
}
