import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Musictrol

// Панель музыки: открывается по центру экрана, фон слегка затемнён.
// Строка поиска с иконками разделов (вариант A), карусель обложек, действия.
Window {
    id: overlay

    property bool opened: false
    signal closed()

    // Разделы
    readonly property int secSearch: 0
    readonly property int secQueue: 1
    readonly property int secPlaylists: 2
    readonly property int secFavorites: 3
    readonly property int secHistory: 4
    property int section: secSearch

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Musictrol — музыка"
    visible: false

    property color accent: Music.accentColor
    Behavior on accent { ColorAnimation { duration: 700 } }

    // ── Открытие / закрытие ──────────────────────────────────────────────
    function open(targetScreen) {
        if (targetScreen)
            screen = targetScreen
        x = screen.virtualX
        y = screen.virtualY
        width = screen.width
        height = screen.height
        hideTimer.stop()
        show()
        raise()
        requestActivate()
        WindowHelper.setupWidgetWindow(overlay, WindowHelper.Above)
        opened = true
        if (section === secQueue)
            carousel.currentIndex = Math.max(0, Music.currentIndex)
        searchField.forceActiveFocus()
        searchField.selectAll()
    }

    function close() {
        if (!opened)
            return
        picker.close()
        opened = false
        hideTimer.restart()
        closed()
    }

    function toggle(targetScreen) {
        opened ? close() : open(targetScreen)
    }

    Timer { id: hideTimer; interval: 280; onTriggered: overlay.hide() }

    // Ушли в другое окно — панель закрывается сама.
    onActiveChanged: if (!active && opened) Qt.callLater(() => { if (!overlay.active) overlay.close() })

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: picker.opened ? picker.close() : overlay.close()
    }
    // Стрелки ↑↓ — всегда листают; ←→ — когда курсор не в строке поиска.
    Shortcut { sequence: "Up"; onActivated: carousel.decrementCurrentIndex() }
    Shortcut { sequence: "Down"; onActivated: carousel.incrementCurrentIndex() }
    Shortcut { sequence: "Left"; onActivated: carousel.decrementCurrentIndex() }
    Shortcut { sequence: "Right"; onActivated: carousel.incrementCurrentIndex() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: carousel.decrementCurrentIndex() }
    Shortcut { sequence: "Ctrl+Right"; onActivated: carousel.incrementCurrentIndex() }

    // ── Данные текущего раздела ──────────────────────────────────────────
    readonly property bool playlistGrid: section === secPlaylists && Library.openedPlaylist < 0
    readonly property var currentModel: {
        switch (section) {
        case secQueue: return Music.queue
        case secPlaylists: return Library.openedPlaylist >= 0 ? Library.openedTracks : Library.playlists
        case secFavorites: return Library.favorites
        case secHistory: return Library.history
        default: return Music.results
        }
    }
    readonly property int itemCount: currentModel ? currentModel.count : 0

    function setSection(s) {
        if (s !== secPlaylists && Library.openedPlaylist >= 0)
            Library.openPlaylist(-1)
        section = s
        carousel.currentIndex = s === secQueue ? Math.max(0, Music.currentIndex) : 0
    }

    function plural(n, one, few, many) {
        const m10 = n % 10, m100 = n % 100
        if (m10 === 1 && m100 !== 11) return one
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few
        return many
    }
    function tracksText(n) { return n + " " + plural(n, "трек", "трека", "треков") }

    readonly property string caption: {
        switch (section) {
        case secQueue: return "Очередь · " + tracksText(itemCount)
        case secPlaylists:
            return Library.openedPlaylist >= 0 ? Library.openedPlaylistName + " · " + tracksText(itemCount)
                                               : "Плейлисты · " + itemCount
        case secFavorites: return "Избранное · " + tracksText(itemCount)
        case secHistory: return "История · " + tracksText(itemCount)
        default:
            if (Music.searching) return "Ищу…"
            return itemCount > 0 ? "Поиск · " + itemCount + " " + plural(itemCount, "результат", "результата", "результатов") : "Поиск"
        }
    }

    readonly property string emptyText: {
        switch (section) {
        case secQueue: return "Очередь пуста"
        case secPlaylists: return Library.openedPlaylist >= 0 ? "Плейлист пуст — добавляйте треки кнопкой «В плейлист»"
                                                               : "Плейлистов пока нет — создайте первый"
        case secFavorites: return "Нажмите ♥ у трека, чтобы добавить его сюда"
        case secHistory: return "Здесь появятся сыгранные треки"
        default: return Music.searching ? "" : "Введите запрос или ссылку и нажмите Enter"
        }
    }

    // mqdefault (320×180) → hq720 (1280×720) для крупной обложки в центре.
    function hiRes(url) { return url ? url.toString().replace("mqdefault", "hq720") : "" }

    function playCurrent() {
        if (itemCount === 0)
            return
        if (playlistGrid) {
            Library.openPlaylist(carousel.currentIndex)
            if (Library.openedTracks.count > 0)
                Music.playFrom(Library.openedTracks, 0)
            return
        }
        Music.playFrom(currentModel, carousel.currentIndex)
    }

    function showToast(text) {
        toast.text = text
        toast.opacity = 1
        toastTimer.restart()
    }

    // ── Затемнение ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.015, 0.04, 0.38)
        opacity: overlay.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: overlay.close()
    }

    // ── Панель ──────────────────────────────────────────────────────────
    GlassPane {
        id: panel
        window: overlay
        width: 640
        height: content.implicitHeight + 32
        x: (overlay.width - width) / 2
        y: Math.round(overlay.height * 0.42 - height / 2)
        radius: 34
        useWallpaper: false
        tintOpacity: 0.88
        shadowBlur: 50
        accent: overlay.accent

        opacity: overlay.opened ? 1 : 0
        scale: overlay.opened ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

        // Клики по панели не должны закрывать её.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            anchors.bottomMargin: 20
            spacing: 14

            // Строка поиска + иконки разделов
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 27
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: searchField.activeFocus ? 1 : 0
                border.color: Qt.alpha(overlay.accent, 0.5)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 7
                    spacing: 8

                    Icon {
                        name: "search"
                        size: 18
                        color: Qt.lighter(overlay.accent, 1.3)
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Поиск на YouTube или ссылка"
                        placeholderTextColor: Theme.faint
                        color: "white"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        background: null
                        selectByMouse: true
                        property string lastQuery: ""
                        onAccepted: {
                            const q = text.trim()
                            if (q.length === 0)
                                return
                            if (q !== lastQuery || overlay.section !== overlay.secSearch) {
                                lastQuery = q
                                overlay.setSection(overlay.secSearch)
                                Music.search(q)
                            } else {
                                overlay.playCurrent()
                            }
                        }
                    }

                    Row {
                        spacing: 2
                        Repeater {
                            model: [
                                { icon: "search", tip: "Поиск" },
                                { icon: "queue", tip: "Очередь" },
                                { icon: "playlists", tip: "Плейлисты" },
                                { icon: "heart", tip: "Избранное" },
                                { icon: "history", tip: "История" }
                            ]
                            delegate: IconButton {
                                required property var modelData
                                required property int index
                                readonly property bool current: overlay.section === index
                                iconName: modelData.icon
                                text: modelData.tip
                                implicitWidth: 40; implicitHeight: 40
                                iconSize: 18
                                iconColor: current ? "white" : "#8d86a3"
                                baseColor: current ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                onClicked: overlay.setSection(index)

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: 4; height: 4; radius: 2
                                    color: overlay.accent
                                    opacity: parent.current ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                    }
                }
            }

            // Подпись раздела (+ назад из плейлиста / новый плейлист)
            Item {
                Layout.fillWidth: true
                implicitHeight: 30

                IconButton {
                    id: backFromPlaylist
                    visible: overlay.section === overlay.secPlaylists && Library.openedPlaylist >= 0
                    iconName: "back"
                    text: "К плейлистам"
                    implicitWidth: 30; implicitHeight: 30
                    iconSize: 16
                    iconColor: Theme.dim
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: { Library.openPlaylist(-1); carousel.currentIndex = 0 }
                }

                Label {
                    anchors.centerIn: parent
                    text: overlay.caption
                    color: "#8d86a3"
                    font.pixelSize: 12
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                }

                // Новый плейлист: кнопка «+» раскрывается в поле ввода названия.
                Row {
                    visible: overlay.playlistGrid
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    TextField {
                        id: newPlaylistName
                        visible: newPlaylistBtn.editing
                        width: 180
                        height: 30
                        placeholderText: "Название плейлиста"
                        placeholderTextColor: Theme.faint
                        color: "white"
                        font.pixelSize: 13
                        leftPadding: 12
                        background: Rectangle { radius: 15; color: Qt.rgba(1, 1, 1, 0.1) }
                        onAccepted: newPlaylistBtn.commit()
                    }
                    IconButton {
                        id: newPlaylistBtn
                        property bool editing: false
                        iconName: editing ? "plus" : "plus"
                        text: editing ? "Создать" : "Новый плейлист"
                        implicitWidth: 30; implicitHeight: 30
                        iconSize: 16
                        iconColor: Qt.lighter(overlay.accent, 1.35)
                        baseColor: Qt.alpha(overlay.accent, 0.18)
                        function commit() {
                            const i = Library.createPlaylist(newPlaylistName.text)
                            newPlaylistName.text = ""
                            editing = false
                            carousel.currentIndex = i
                            searchField.forceActiveFocus()
                        }
                        onClicked: {
                            if (editing) {
                                commit()
                            } else {
                                editing = true
                                newPlaylistName.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // Карусель обложек
            Item {
                Layout.fillWidth: true
                implicitHeight: 190

                PathView {
                    id: carousel
                    anchors.fill: parent
                    model: overlay.currentModel
                    pathItemCount: 5
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    snapMode: PathView.SnapToItem
                    highlightMoveDuration: 420
                    interactive: true
                    clip: true

                    path: Path {
                        startX: 0; startY: carousel.height / 2
                        PathAttribute { name: "itemScale"; value: 0.42 }
                        PathAttribute { name: "itemAngle"; value: 50 }
                        PathAttribute { name: "itemOpacity"; value: 0.25 }
                        PathAttribute { name: "itemZ"; value: 0 }
                        PathLine { x: carousel.width / 2; y: carousel.height / 2 }
                        PathAttribute { name: "itemScale"; value: 1 }
                        PathAttribute { name: "itemAngle"; value: 0 }
                        PathAttribute { name: "itemOpacity"; value: 1 }
                        PathAttribute { name: "itemZ"; value: 10 }
                        PathLine { x: carousel.width; y: carousel.height / 2 }
                        PathAttribute { name: "itemScale"; value: 0.42 }
                        PathAttribute { name: "itemAngle"; value: -50 }
                        PathAttribute { name: "itemOpacity"; value: 0.25 }
                        PathAttribute { name: "itemZ"; value: 0 }
                    }

                    delegate: Item {
                        id: tile
                        required property int index
                        required property var model
                        readonly property bool isCurrent: PathView.isCurrentItem
                        readonly property bool isPlaylist: overlay.playlistGrid
                        readonly property string itemTitle: isPlaylist ? (model.name ?? "") : (model.title ?? "")
                        readonly property string itemSubtitle: isPlaylist
                            ? overlay.tracksText(model.trackCount ?? 0)
                            : (model.artist ?? "") + ((model.duration ?? 0) > 0 ? " · " + Music.formatTime(model.duration) : "")
                        readonly property bool nowPlaying: overlay.section === overlay.secQueue && index === Music.currentIndex

                        width: 170
                        height: 170
                        scale: PathView.itemScale
                        opacity: PathView.itemOpacity
                        z: PathView.itemZ
                        transform: Rotation {
                            origin.x: tile.width / 2
                            origin.y: tile.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: tile.PathView.itemAngle ?? 0
                        }

                        // Обложка трека
                        Item {
                            anchors.fill: parent
                            visible: !tile.isPlaylist
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: Qt.rgba(1, 1, 1, 0.06)
                            }
                            RoundedImage {
                                anchors.fill: parent
                                radius: 18
                                source: tile.isCurrent ? overlay.hiRes(tile.model.thumbnail) : (tile.model.thumbnail ?? "")
                                fallbackSource: tile.model.thumbnail ?? ""
                            }
                        }

                        // Мозаика плейлиста (до 4 обложек) со скруглёнными углами
                        Item {
                            anchors.fill: parent
                            visible: tile.isPlaylist

                            Grid {
                                id: mosaic
                                anchors.fill: parent
                                columns: 2
                                visible: false
                                Repeater {
                                    model: tile.isPlaylist ? 4 : 0
                                    delegate: Item {
                                        required property int index
                                        width: 85; height: 85
                                        readonly property var covers: tile.model.covers ?? []
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(1, 1, 1, 0.05 + 0.03 * parent.index)
                                        }
                                        Image {
                                            anchors.fill: parent
                                            source: parent.index < parent.covers.length ? parent.covers[parent.index] : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize: Qt.size(170, 170)
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                id: mosaicMask
                                anchors.fill: parent
                                radius: 18
                                layer.enabled: true
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: mosaic
                                maskEnabled: true
                                maskSource: mosaicMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }
                        }
                        Rectangle {
                            visible: tile.isPlaylist
                            anchors.fill: parent
                            radius: 18
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            Icon {
                                anchors.centerIn: parent
                                name: "playlists"
                                size: 34
                                color: Qt.rgba(1, 1, 1, 0.5)
                                visible: (tile.model.trackCount ?? 0) === 0
                            }
                        }

                        // Обводка и свечение у центральной
                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: "transparent"
                            border.width: tile.isCurrent ? 2 : 0
                            border.color: Qt.rgba(1, 1, 1, 0.85)
                        }

                        Rectangle {
                            visible: tile.nowPlaying
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -10
                            width: nowLabel.implicitWidth + 18
                            height: 22
                            radius: 11
                            color: overlay.accent
                            Label {
                                id: nowLabel
                                anchors.centerIn: parent
                                text: "Сейчас"
                                color: "white"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        TapHandler {
                            onTapped: tile.isCurrent ? overlay.playCurrent() : (carousel.currentIndex = tile.index)
                        }
                    }

                    WheelHandler {
                        onWheel: (e) => {
                            const d = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x
                            if (d < 0) carousel.incrementCurrentIndex()
                            else if (d > 0) carousel.decrementCurrentIndex()
                        }
                    }
                }

                // Пустое состояние
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: overlay.itemCount === 0
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: ["search", "queue", "playlists", "heart", "history"][overlay.section]
                        size: 34
                        color: Qt.rgba(1, 1, 1, 0.25)
                        visible: !Music.searching || overlay.section !== overlay.secSearch
                    }
                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: Music.searching && overlay.section === overlay.secSearch
                        visible: running
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: overlay.emptyText
                        color: Theme.faint
                        font.pixelSize: 13
                    }
                }
            }

            // Название выбранного
            Column {
                Layout.fillWidth: true
                spacing: 3
                opacity: overlay.itemCount > 0 ? 1 : 0
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: carousel.currentItem ? carousel.currentItem.itemTitle : ""
                    color: "white"
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    leftPadding: 30; rightPadding: 30
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: carousel.currentItem ? carousel.currentItem.itemSubtitle : ""
                    color: Theme.dim
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    leftPadding: 30; rightPadding: 30
                }
            }

            // Действия
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: overlay.itemCount > 0

                PillButton {
                    text: overlay.playlistGrid ? "Играть всё" : "Играть"
                    primary: true
                    onClicked: overlay.playCurrent()
                }
                PillButton {
                    visible: overlay.playlistGrid
                    text: "Открыть"
                    onClicked: Library.openPlaylist(carousel.currentIndex)
                }
                PillButton {
                    visible: !overlay.playlistGrid && overlay.section !== overlay.secQueue
                    text: "В очередь"
                    onClicked: {
                        Music.enqueue(overlay.currentModel, carousel.currentIndex)
                        overlay.showToast("Добавлено в очередь")
                    }
                }
                PillButton {
                    visible: !overlay.playlistGrid
                    text: "В плейлист"
                    onClicked: picker.openFor(overlay.currentModel, carousel.currentIndex)
                }
                IconButton {
                    visible: !overlay.playlistGrid
                    readonly property string vid: carousel.currentItem && carousel.currentItem.model ? (carousel.currentItem.model.videoId ?? "") : ""
                    readonly property bool fav: Library.favoritesRevision >= 0 && Library.isFavorite(vid)
                    iconName: fav ? "heartFill" : "heart"
                    text: fav ? "Убрать из избранного" : "В избранное"
                    implicitWidth: 40; implicitHeight: 40
                    iconSize: 18
                    iconColor: fav ? Qt.lighter(overlay.accent, 1.3) : Theme.fg
                    baseColor: Qt.rgba(1, 1, 1, 0.1)
                    onClicked: Library.toggleFavorite(overlay.currentModel, carousel.currentIndex)
                }
                // Убрать из очереди / плейлиста, удалить плейлист
                IconButton {
                    visible: overlay.section === overlay.secQueue
                             || (overlay.section === overlay.secPlaylists)
                    iconName: "trash"
                    text: overlay.playlistGrid ? "Удалить плейлист"
                          : overlay.section === overlay.secQueue ? "Убрать из очереди" : "Убрать из плейлиста"
                    implicitWidth: 40; implicitHeight: 40
                    iconSize: 17
                    iconColor: "#ff8a95"
                    baseColor: Qt.rgba(1, 0.16, 0.21, 0.12)
                    onClicked: {
                        const i = carousel.currentIndex
                        if (overlay.playlistGrid)
                            Library.deletePlaylist(i)
                        else if (overlay.section === overlay.secQueue)
                            Music.removeFromQueue(i)
                        else
                            Library.removeFromOpenedPlaylist(i)
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: Music.errorText.length > 0
                text: Music.errorText
                color: "#ff8a95"
                font.pixelSize: 12
            }
        }

        // Короткие уведомления («Добавлено в очередь»)
        Rectangle {
            id: toast
            property alias text: toastLabel.text
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 14
            width: toastLabel.implicitWidth + 28
            height: 34
            radius: 17
            color: Qt.rgba(0.08, 0.06, 0.12, 0.95)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            opacity: 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Timer { id: toastTimer; interval: 1600; onTriggered: toast.opacity = 0 }
            Label { id: toastLabel; anchors.centerIn: parent; color: Theme.fg; font.pixelSize: 13 }
        }
    }

    PlaylistPicker {
        id: picker
        accent: overlay.accent
        x: panel.x + (panel.width - width) / 2
        y: panel.y + panel.height - height - 70
        onAdded: (name) => overlay.showToast("Добавлено в «" + name + "»")
    }
}
