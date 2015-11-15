import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: self
    property string action
    property rect area
    property alias text: lbl.text
    property color hintColor: "green"
    property real hintOpacity: 1.0

    x: area.x
    y: area.y
    width: area.width
    height: area.height

    Rectangle {
        anchors.fill: parent
        border { color: self.hintColor; width: 4 }
        color: Qt.rgba(1.0 - hintColor.r, 1.0 - hintColor.g, 1.0 - hintColor.b, hintColor.a)
        opacity: self.hintOpacity
    }
    Label {
        id: lbl
        font.pixelSize: Theme.itemSizeMedium
        color: self.hintColor
        anchors.centerIn: parent
        opacity: self.hintOpacity > 0 ? 1.0 : 0.0
    }
}
