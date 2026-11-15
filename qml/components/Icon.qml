import QtQuick
import QtQuick.Shapes
import Musictrol

// Векторная иконка в одном тонком стиле (сетка 24×24), цвет задаётся свойством.
Item {
    id: root

    property string name
    property color color: Theme.fg
    property real size: 20
    property real strokeWidth: 2

    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        "prev":     "M19 5L9 12L19 19Z M5 5V19",
        "next":     "M5 5L15 12L5 19Z M19 5V19",
        "play":     "M8 5V19L19 12Z",
        "pause":    "M9 5V19 M15 5V19",
        "lyrics":   "M4 6H20 M4 12H14 M4 18H17",
        "capsule":  "M12 19V5 M6 11L12 5L18 11",
        "search":   "M11 4A7 7 0 1 1 11 18A7 7 0 1 1 11 4Z M20 20L16.5 16.5",
        "settings": "M4 6H13 M17 6H20 M13 4V8 M4 12H7 M11 12H20 M7 10V14 M4 18H15 M19 18H20 M15 16V20",
        "back":     "M15 18L9 12L15 6",
        "pin":      "M12 17V22 M9 3H15L14 10L18 13V15H6V13L10 10Z",
        "power":    "M12 3V12 M6.3 6.3A8 8 0 1 0 17.7 6.3",
        "volume":   "M11 5L6 9H2V15H6L11 19Z M15.5 8.5A5 5 0 0 1 15.5 15.5 M19 5A10 10 0 0 1 19 19",
        "mute":     "M11 5L6 9H2V15H6L11 19Z M16 9L22 15 M22 9L16 15",
        "music":    "M9 18V5L21 3V16 M9 18A3 3 0 1 1 3 18A3 3 0 1 1 9 18Z M21 16A3 3 0 1 1 15 16A3 3 0 1 1 21 16Z"
    })
    readonly property var filled: ({ "play": true })

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            scale: Qt.size(root.size / 24, root.size / 24)
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: root.filled[root.name] ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.paths[root.name] ?? "" }
        }
    }
}
