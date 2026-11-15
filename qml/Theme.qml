pragma Singleton
import QtQuick

// Общие цвета и размеры всех виджетов.
QtObject {
    readonly property color fg: "#f4f1fb"
    readonly property color dim: "#c9c2dc"
    readonly property color faint: "#a79fbe"
    readonly property color dark: "#140f20"
    readonly property color brand: "#ff2a36"
    readonly property color glassTint: "#141020"
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.14)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)

    readonly property int radiusCard: 22
    readonly property int durFast: 120
    readonly property int durMid: 260
}
