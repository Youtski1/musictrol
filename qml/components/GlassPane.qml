import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Window
import Musictrol

// «Стекло»: кусок заранее размытых обоев ровно под этим местом экрана,
// тёмная тонировка и мягкий отсвет цветом обложки. Блюр не считается
// каждый кадр — картинку готовит Wallpaper один раз.
Item {
    id: pane

    required property Window window
    // Где эта панель внутри окна (для совмещения с обоями).
    property real originX: 0
    property real originY: 0
    property real radius: Theme.radiusCard
    property real tintOpacity: 0.55
    property color accent: Theme.brand

    default property alias content: holder.data

    RectangularShadow {
        anchors.fill: glass
        radius: pane.radius
        blur: 36
        offset.y: 14
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Item {
        id: glass
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Image {
            source: Wallpaper.revision >= 0 ? Wallpaper.blurredFor(pane.Screen.name) : ""
            x: -(pane.window.x + pane.originX - pane.Screen.virtualX)
            y: -(pane.window.y + pane.originY - pane.Screen.virtualY)
            width: pane.Screen.width
            height: pane.Screen.height
            smooth: true
            cache: false
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.glassTint
            opacity: pane.tintOpacity
        }

        // Отсвет обложки из верхнего левого угла.
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 0; centerY: 0
                    focalX: 0; focalY: 0
                    centerRadius: Math.max(glass.width, glass.height) * 0.9
                    GradientStop { position: 0; color: Qt.alpha(pane.accent, 0.26) }
                    GradientStop { position: 1; color: Qt.alpha(pane.accent, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: glass.width; y: 0 }
                PathLine { x: glass.width; y: glass.height }
                PathLine { x: 0; y: glass.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: pane.radius
        layer.enabled: true
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        radius: pane.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.glassBorder
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
