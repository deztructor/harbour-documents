import QtQuick 2.0
import Sailfish.Silica 1.0
import Documents 1.0

Page {
    id: page

    allowedOrientations: Orientation.All
    showNavigationIndicator: doc.state != Document.Loaded

    property string filePath
    property string mimeType

    DocumentSettings {
        id: docSettings
        zoom: view.zoom
    }

    InfoLabel {
        visible: doc.state == Document.Error
        text: qsTr("Failed to open document")
        anchors.centerIn: parent
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: doc.state == Document.Loading
    }

    SilicaFlickable {
        id: flick
        contentX: docSettings.position.x
        contentY: docSettings.position.y
        onMovingChanged: {
            if (!flick.moving) {
                docSettings.position = Qt.point(flick.contentX, flick.contentY)
            }
        }

        anchors.fill: parent
        contentWidth: doc.width * view.dpiX
        contentHeight: doc.height * view.dpiY
        boundsBehavior: Flickable.StopAtBounds

        function updateCurrentPosition(newY) {
            contentY = newY
            docSettings.position = Qt.point(contentX, contentY)
        }

        function scrollToPageAndPop(page) {
            pageStack.pop()
            updateCurrentPosition(doc.pagePosition(page) * view.dpiY)
        }

        readonly property int maxPosition: contentHeight - height

        function pagePrev(pos) {
            var overlap = height / 16 + (pos ? pos.y : 0)
            var newY = flick.contentY - height + overlap
            updateCurrentPosition(newY > 0 ? newY : 0)
        }
        function pageNext(pos) {
            var overlap = height / 16 + (pos ? height - pos.y : 0)
            var newY = flick.contentY + height - overlap
            updateCurrentPosition(newY > maxPosition ? maxPosition : newY)
        }

        Document {
            id: doc
            Component.onCompleted: init(page.filePath, page.mimeType)

            onStateChanged: {
                if (doc.state == Document.Loaded) {
                    docSettings.load(doc.filePath)
                } else if (doc.state == Document.Locked) {
                    pageStack.completeAnimation()
                    var dlg = pageStack.push(Qt.resolvedUrl("UnlockDialog.qml"))
                    dlg.rejected.connect(function() {
                        // We will just pass any password and hope it does not work
                        // since there is no way I am aware off to easily pop this page
                        // without hacks. I'd rather show the error.
                        doc.unlockDocument("")
//                        pageStack.completeAnimation()
//                        pageStack.pop()
                    })

                    dlg.accepted.connect(function() {
                        doc.unlockDocument(dlg.password)
                    })
                 }
            }
        }

        PinchArea {
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)
            pinch {
                target: view
                minimumScale: 0.5
                maximumScale: 2
            }

            onPinchFinished: {
                var x = pinch.center.x * view.scale
                var y = pinch.center.y * view.scale
                var xpos = pinch.center.x - flick.contentX
                var ypos = pinch.center.y - flick.contentY
                flick.contentX = x - xpos
                flick.contentY = y - ypos
                view.zoom *= view.scale
                view.scale = 1.0
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.processClick(mouse)
                onPressAndHold: page.showHint("stickyHint")
                onReleased: {
                    if (page.state === "stickyHint")
                        page.hideHint()
                }
            }
        }
    }

    DocumentView {
        id: view
        anchors.fill: flick
        document: doc.state == Document.Loaded ? doc : null
        contentX: flick.contentX
        contentY: flick.contentY
        zoom: docSettings.zoom
    }
    property point activeAreasCount: Qt.point(1, 5)
    property point activeAreaSize: Qt.point(flick.width / activeAreasCount.x
                                            , flick.height / activeAreasCount.y)
    // from/to are quadrants
    function activeAreaRect(fromX, fromY, toX, toY) {
        var dx = toX - fromX
        var dy = toY - fromY
        return Qt.rect(activeAreaSize.x * fromX, activeAreaSize.y * fromY,
                       activeAreaSize.x * dx, activeAreaSize.y * dy)
    }

    readonly property var activeAreas: [
        { action: "pageUp",
          area: activeAreaRect(0, 0, 1, 2),
          hintColor: "green",
          text: "Page Up"
        },
        { action: "toggleMenu",
          area: activeAreaRect(0, 2, 1, 3),
          hintColor: "red",
          text: "Toggle Menu"
        },
        { action: "pageDown",
          area: activeAreaRect(0, 3, 1, 5),
          hintColor: "blue",
          text: "Page Down"
        }
    ]

    function withinArea(pos, area) {
        return (pos.x >= area.x && pos.y >= area.y
                && pos.x - area.x < area.width
                && pos.y - area.y < area.height)
    }

    property real hintOpacity: 0.0
    Behavior on hintOpacity { FadeAnimation {} }

    Timer {
        id: hideHintsTimer
        interval: 700
        onTriggered: page.hideHint()
    }

    property variant areas: []
    Component.onCompleted: {
        showHint()
        for (var i = 0; i < activeAreas.length; ++i) {
            areaHintComponent.createObject(page, activeAreas[i]);
        }
    }

    function invokeAction(context, pos) {
        var name = context.action
        switch (name) {
        case "pageUp":
            flick.pagePrev(pos)
            break
        case "pageDown":
            flick.pageNext(pos)
            break
        case "toggleMenu":
            tools.shown = !tools.shown
            break
        default:
            console.log("Unknown action", name)
            break
        }
    }

    function processClick(mouse) {
        var pos = Qt.point(mouse.x - flick.contentX,
                           mouse.y - flick.contentY)
        for (var i = 0; i < activeAreas.length; ++i) {
            var context = activeAreas[i]
            if (withinArea(pos, context.area)) {
                invokeAction(context, pos)
                return
            }
        }
        showHint()
    }

    function showHint(newState) {
        hintOpacity = 0.3
        if (!newState)
            hideHintsTimer.running = true
        else
            state = newState
    }

    function hideHint() {
        hintOpacity = 0.0
        state = ""
    }

    Component {
        id: areaHintComponent
        AreaHint {
            hintOpacity: page.hintOpacity
        }
    }

    Item {
        id: tools
        property bool shown: false
        property bool _shown: shown && view.scale == 1.0 && doc.state == Document.Loaded
        visible: height > 0
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: _shown ? Theme.itemSizeMedium + spacing * 2 : 0
        property int spacing: Theme.paddingMedium
        Rectangle {
            opacity: tools.shown ? 0.4 : 0.0
            anchors.fill: parent
            color: "black"
            Behavior on opacity { FadeAnimation {} }
        }
        Row {
            spacing: parent.spacing

            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }

            Behavior on height {
                NumberAnimation { duration: 200 }
            }

            ZoomingButton {
                icon.source: "image://svg/books.svg"
                onClicked: pageStack.pop()
            }

            ZoomingButton {
                icon.source: "image://svg/info.svg"
                onClicked: pageStack.push(Qt.resolvedUrl("DocumentDetailsPage.qml"), {doc: doc})
            }

            ZoomingButton {
                icon.source: "image://svg/page-prev.svg"
                enabled: flick.contentY > 0
                onClicked: flick.pagePrev()
            }
            ZoomingButton {
                icon.source: "image://svg/page-next.svg"
                enabled: flick.contentY < flick.maxPosition
                onClicked: flick.pageNext()
            }
            ZoomingButton {
                icon.source: "image://svg/pages.svg"
                onClicked: {
                    var page = pageStack.push(Qt.resolvedUrl("DocumentIndexPage.qml"), {doc: doc})
                    page.scrollTo.connect(flick.scrollToPageAndPop)
                }
            }
            ZoomingButton {
                icon.source: "image://svg/toc.svg"
                onClicked: {
                    var page = pageStack.push(Qt.resolvedUrl("DocumentOutlinePage.qml"), {doc: doc})
                    page.scrollTo.connect(flick.scrollToPageAndPop)
                }
            }
        }
    }
}
