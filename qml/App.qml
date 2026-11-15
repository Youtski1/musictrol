import QtQuick
import Musictrol

// Корень приложения: держит все окна-виджеты.
QtObject {
    id: app

    property DevWindow searchWindow: DevWindow {
        visible: false
    }

    // Режим разработчика: --snapshot <папка> — снимки карточки (плеер и настройки).
    readonly property int snapshotArg: Qt.application.arguments.indexOf("--snapshot")
    property Timer snapshotTimer: Timer {
        running: app.snapshotArg > 0
        interval: 2500
        property int step: 0
        repeat: true
        onTriggered: {
            const dir = Qt.application.arguments[app.snapshotArg + 1]
            const item = app.mainWidget.contentItem
            if (step === 0) {
                item.grabToImage(r => r.saveToFile(dir + "/player.png"))
                app.mainWidget.setSettingsOpen(true)
            } else if (step === 1) {
                item.grabToImage(r => r.saveToFile(dir + "/settings.png"))
                app.mainWidget.setSettingsOpen(false)
            } else {
                item.grabToImage(r => { r.saveToFile(dir + "/player-again.png"); Qt.quit() })
                stop()
            }
            step++
        }
    }

    property MainWidget mainWidget: MainWidget {
        // Временно (до шага 3): поиск открывает тестовое окно.
        onSearchRequested: {
            app.searchWindow.show()
            app.searchWindow.raise()
            app.searchWindow.requestActivate()
        }
    }
}
