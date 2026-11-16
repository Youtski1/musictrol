import QtQuick

// Картинка со скруглёнными углами (обложки). Если основная картинка
// не загрузилась (например, большой обложки у видео нет) — берётся запасная.
// Скругление и обрезка делаются маленьким шейдером прямо при выводе — без
// промежуточных текстур и маски (раньше был MultiEffect: лишняя видеопамять).
Item {
    id: root

    property url source
    property url fallbackSource
    property real radius: 12
    readonly property bool ready: img.status === Image.Ready

    property bool useFallback: false
    onSourceChanged: useFallback = false

    Image {
        id: img
        anchors.fill: parent
        source: root.useFallback ? root.fallbackSource : root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        // Текстура не больше, чем нужно на экране (×2 для чёткости на HiDPI).
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        visible: false
        onStatusChanged: {
            if (status === Image.Error && !root.useFallback && root.fallbackSource.toString() !== "")
                root.useFallback = true
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.ready
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        property variant source: img
        property size itemSize: Qt.size(width, height)
        property real radius: Math.min(root.radius, width / 2, height / 2)
        // Какая доля текстуры видна при заполнении с обрезкой.
        readonly property real texW: Math.max(1, img.implicitWidth)
        readonly property real texH: Math.max(1, img.implicitHeight)
        readonly property real fillScale: Math.max(width / texW, height / texH)
        property size crop: Qt.size(Math.min(1, width / (texW * fillScale)), Math.min(1, height / (texH * fillScale)))

        fragmentShader: "qrc:/shaders/rounded.frag.qsb"
    }
}
