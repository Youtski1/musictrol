import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Musictrol

// Всплывающий выбор плейлиста для «В плейлист» (+ создание нового).
Popup {
    id: picker

    property color accent: Theme.brand
    property var sourceModel: null
    property int sourceIndex: -1

    signal added(string playlistName)

    function openFor(model, index) {
        sourceModel = model
        sourceIndex = index
        open()
    }

    function addTo(playlist) {
        Library.addToPlaylist(playlist, sourceModel, sourceIndex)
        added(Library.playlistName(playlist))
        close()
    }

    width: 300
    padding: 10
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 }
    }

    background: Rectangle {
        radius: 18
        color: Qt.rgba(0.07, 0.055, 0.1, 0.98)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
    }

    contentItem: ColumnLayout {
        spacing: 6

        Label {
            text: "Добавить в плейлист"
            color: Theme.faint
            font.pixelSize: 12
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
            Layout.leftMargin: 8
            Layout.topMargin: 4
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 220)
            clip: true
            model: Library.playlists
            spacing: 2
            delegate: AbstractButton {
                id: row
                required property int index
                required property string name
                required property int trackCount
                width: ListView.view.width
                implicitHeight: 40
                hoverEnabled: true
                onClicked: picker.addTo(index)
                background: Rectangle {
                    radius: 10
                    color: row.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 10
                    Icon { name: "playlists"; size: 16; color: Theme.dim; Layout.leftMargin: 8 }
                    Label { text: row.name; color: Theme.fg; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                    Label { text: row.trackCount; color: Theme.faint; font.pixelSize: 12; Layout.rightMargin: 8 }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08); visible: Library.playlists.count > 0 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id: nameField
                Layout.fillWidth: true
                implicitHeight: 36
                placeholderText: "Новый плейлист…"
                placeholderTextColor: Theme.faint
                color: "white"
                font.pixelSize: 13
                leftPadding: 12
                background: Rectangle { radius: 18; color: Qt.rgba(1, 1, 1, 0.08) }
                onAccepted: createBtn.clicked()
            }
            IconButton {
                id: createBtn
                iconName: "plus"
                text: "Создать и добавить"
                implicitWidth: 36; implicitHeight: 36
                iconSize: 16
                iconColor: Qt.lighter(picker.accent, 1.35)
                baseColor: Qt.alpha(picker.accent, 0.2)
                onClicked: {
                    const i = Library.createPlaylist(nameField.text)
                    nameField.text = ""
                    Library.addToPlaylist(i, picker.sourceModel, picker.sourceIndex)
                    picker.added(Library.playlistName(i))
                    picker.close()
                }
            }
        }
    }
}
