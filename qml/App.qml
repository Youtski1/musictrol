import QtQuick
import Musictrol

// Корень приложения: держит все окна-виджеты и связывает их.
QtObject {
    id: app

    property MusicPanel panel: MusicPanel {}

    property MiniWidget mini: MiniWidget {
        panelOpen: app.panel.opened
        onTogglePanel: app.panel.toggle(screen)
    }

    property MainWidget mainWidget: MainWidget {
        onSearchRequested: app.panel.open(screen)
    }

    // Повторный запуск программы — открыть панель музыки.
    property Connections activation: Connections {
        target: AppSettings
        function onActivateRequested() { app.panel.open(app.mini.screen) }
    }

    // Режим разработчика: --snapshot <папка> — снимки виджетов.
    readonly property int snapshotArg: Qt.application.arguments.indexOf("--snapshot")
    property Timer snapshotTimer: Timer {
        running: app.snapshotArg > 0
        interval: 2500
        property int step: 0
        repeat: true
        onTriggered: {
            const dir = Qt.application.arguments[app.snapshotArg + 1]
            const main = app.mainWidget.contentItem
            switch (step) {
            case 0:
                main.grabToImage(r => r.saveToFile(dir + "/player.png"))
                app.mini.contentItem.grabToImage(r => r.saveToFile(dir + "/mini.png"))
                app.mainWidget.peekVolume()
                Music.search("lofi hip hop")
                interval = 600
                break
            case 1:
                main.grabToImage(r => r.saveToFile(dir + "/volume.png"))
                app.mainWidget.setSettingsOpen(true)
                interval = 2500
                break
            case 2:
                main.grabToImage(r => r.saveToFile(dir + "/settings.png"))
                app.mainWidget.setSettingsOpen(false)
                app.panel.open(app.mini.screen)
                break
            case 3:
                app.panel.contentItem.grabToImage(r => r.saveToFile(dir + "/panel.png"))
                interval = 900
                break
            case 4:
                app.panel.setSection(app.panel.secPlaylists)
                break
            case 5:
                app.panel.contentItem.grabToImage(r => { r.saveToFile(dir + "/panel-playlists.png"); Qt.quit() })
                stop()
                break
            }
            step++
        }
    }
}
