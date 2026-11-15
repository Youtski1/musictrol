import QtQuick
import Musictrol

// Корень приложения: держит все окна-виджеты.
QtObject {
    id: app

    property DevWindow searchWindow: DevWindow {
        visible: false
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
