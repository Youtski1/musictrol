import QtQuick
import QtCore
import Musictrol

// Корень приложения: держит все окна-виджеты и связывает их.
QtObject {
    id: app

    property MusicPanel panel: MusicPanel {}

    // Поведение капсулы в играх: "hud" | "hide" | "normal".
    property Settings gamePrefs: Settings {
        category: "Game"
        property string behavior: "hud"
    }

    property MiniWidget mini: MiniWidget {
        panelOpen: app.panel.opened
        gameBehavior: app.gamePrefs.behavior
        onTogglePanel: app.panel.toggle(screen)
    }

    property MainWidget mainWidget: MainWidget {
        onSearchRequested: app.panel.open(app.mini.screen)
        onCapsuleRequested: app.mini.setWaveMode(!app.mini.waveMode)
        gameBehavior: app.gamePrefs.behavior
        onGameBehaviorChosen: (b) => app.gamePrefs.behavior = b
    }

    // Глобальные горячие клавиши.
    property Connections hotkeys: Connections {
        target: GlobalHotkeys
        function onTriggered(id) {
            switch (id) {
            case "panel":
                // В игре — живая полоса с клавиатуры (игра остаётся активной),
                // иначе — панель музыки.
                if (app.mini.gameMode) {
                    if (!app.mini.enterInteractive())
                        app.mini.setWaveMode(!app.mini.waveMode)
                } else {
                    app.panel.toggle(app.mini.screen)
                }
                break
            case "playPause": Music.togglePause(); break
            case "next": Music.next(); break
            case "prev": Music.previous(); break
            case "volUp":
                Music.player.muted = false
                Music.player.volume = Math.min(100, Music.player.volume + 5)
                break
            case "volDown": Music.player.volume = Math.max(0, Music.player.volume - 5); break
            case "wave": app.mini.setWaveMode(!app.mini.waveMode); break
            }
        }
    }

    // Повторный запуск программы — открыть панель музыки.
    property Connections activation: Connections {
        target: AppSettings
        function onActivateRequested() { app.panel.open(app.mini.screen) }
    }

    // Режим разработчика: --snapshot <папка> — снимки виджетов по шагам.
    readonly property int snapshotArg: Qt.application.arguments.indexOf("--snapshot")
    property Timer snapshotTimer: Timer {
        running: app.snapshotArg > 0
        interval: 2500
        repeat: true
        property int step: 0
        onTriggered: {
            const dir = Qt.application.arguments[app.snapshotArg + 1]
            const save = (win, name) => win.contentItem.grabToImage(r => r.saveToFile(dir + "/" + name + ".png"))
            const steps = [
                () => {
                    save(app.mainWidget, "player")
                    save(app.mini, "capsule-circle")
                    console.log("hotkeys:", JSON.stringify(GlobalHotkeys.actions.map(a => a.id + "=" + a.sequence + ":" + a.status)))
                    app.mainWidget.setSettingsOpen(true)
                    app.mainWidget.showHotkeysPage(true)
                    interval = 1500
                },
                () => {
                    save(app.mainWidget, "hotkeys")
                    app.mainWidget.setSettingsOpen(false)
                    app.mini.forceExpanded(true)
                    interval = 900
                },
                () => {
                    save(app.mini, "capsule-expanded")
                    app.mini.forceExpanded(false)
                    app.mini.setWaveMode(true)
                },
                () => {
                    save(app.mini, "capsule-wave")
                    app.mini.setWaveMode(false)
                    app.mini.previewInteractive = true
                    interval = 1200
                },
                () => {
                    save(app.mini, "game-interactive")
                    app.mini.query = "дора"
                    app.mini.lastQuery = "дора"
                    Music.search("дора")
                    interval = 6000
                },
                () => {
                    save(app.mini, "game-search")
                    app.panel.open(app.mini.screen)
                    interval = 1200
                },
                () => {
                    app.mini.previewInteractive = false
                    app.panel.contentItem.grabToImage(r => { r.saveToFile(dir + "/panel.png"); Qt.quit() })
                    stop()
                }
            ]
            steps[step++]()
        }
    }
}
