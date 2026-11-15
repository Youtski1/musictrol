import QtQuick
import QtQuick.Effects

// Картинка со скруглёнными углами (обложки).
Item {
    id: root

    property url source
    property real radius: 12
    readonly property bool ready: img.status === Image.Ready

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        visible: false
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
}
