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
        onSearchRequested: app.panel.open(app.mini.screen)
        onCapsuleRequested: app.mini.setWaveMode(!app.mini.waveMode)
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
            const save = (win, name) => win.contentItem.grabToImage(r => r.saveToFile(dir + "/" + name + ".png"))
            switch (step) {
            case 0:
                save(app.mainWidget, "player")
                save(app.mini, "capsule-circle")
                app.mini.forceExpanded(true)
                interval = 900
                break
            case 1:
                save(app.mini, "capsule-expanded")
                app.mini.forceExpanded(false)
                app.mini.setWaveMode(true)
                break
            case 2:
                save(app.mini, "capsule-wave")
                app.mini.setWaveMode(false)
                app.panel.open(app.mini.screen)
                interval = 1200
                break
            case 3:
                app.panel.contentItem.grabToImage(r => { r.saveToFile(dir + "/panel.png"); Qt.quit() })
                stop()
                break
            }
            step++
        }
    }
}
