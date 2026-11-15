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
        "close":    "M6 6L18 18 M18 6L6 18",
        "down":     "M6 9L12 15L18 9",
        "ripples":  "M12 9.5A2.5 2.5 0 1 1 12 14.5A2.5 2.5 0 1 1 12 9.5Z M7.8 7.8A6 6 0 0 0 7.8 16.2 M16.2 7.8A6 6 0 0 1 16.2 16.2 M5 5A10 10 0 0 0 5 19 M19 5A10 10 0 0 1 19 19",
        "wave":     "M3 12H5 M7 8V16 M11 5V19 M15 9V15 M19 11V13",
        "corner":   "M17 7L7 17 M7 9V17H15",
        "up":       "M18 15L12 9L6 15",
        "heart":    "M12 20C12 20 3.5 14.8 3.5 9.2A4.3 4.3 0 0 1 12 7.2A4.3 4.3 0 0 1 20.5 9.2C20.5 14.8 12 20 12 20Z",
        "heartFill": "M12 20C12 20 3.5 14.8 3.5 9.2A4.3 4.3 0 0 1 12 7.2A4.3 4.3 0 0 1 20.5 9.2C20.5 14.8 12 20 12 20Z",
        "queue":    "M4 6H16 M4 12H16 M4 18H11 M18 15V21 M15 18H21",
        "playlists": "M4 4H10V10H4Z M14 4H20V10H14Z M4 14H10V20H4Z M14 14H20V20H14Z",
        "history":  "M12 3A9 9 0 1 1 12 21A9 9 0 1 1 12 3Z M12 7V12L15 14",
        "plus":     "M12 5V19 M5 12H19",
        "trash":    "M4 7H20 M10 11V17 M14 11V17 M6 7L7 20H17L18 7 M9 7V4H15V7",
        "listAdd":  "M4 6H14 M4 12H14 M4 18H10 M17 13V21 M13 17H21",
        "pin":"M12 17V22 M9 3H15L14 10L18 13V15H6V13L10 10Z",
        "power":    "M12 3V12 M6.3 6.3A8 8 0 1 0 17.7 6.3",
        "volume":   "M11 5L6 9H2V15H6L11 19Z M15.5 8.5A5 5 0 0 1 15.5 15.5 M19 5A10 10 0 0 1 19 19",
        "mute":     "M11 5L6 9H2V15H6L11 19Z M16 9L22 15 M22 9L16 15",
        "music":    "M9 18V5L21 3V16 M9 18A3 3 0 1 1 3 18A3 3 0 1 1 9 18Z M21 16A3 3 0 1 1 15 16A3 3 0 1 1 21 16Z"
    })
    readonly property var filled: ({ "play": true, "heartFill": true })

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
