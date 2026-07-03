import QtQuick
import QtQuick.Window

import "components"
import "effects"

Window {
    id: root

    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    property int exitCodeToReturn: 0
    property bool closing: false
    readonly property int animDuration: Style.animations.normal

    Shortcut {
        sequence: "Escape"
        onActivated: root.requestClose(0)
    }

    function requestClose(exitCode) {
        if (root.closing)
            return;

        root.closing = true;
        root.exitCodeToReturn = exitCode;
        backdrop.fadeOut();
        actionPanel.startExit();
    }

    Backdrop {
        id: backdrop
        anchors.fill: parent
        animDuration: root.animDuration
        onDismissed: root.requestClose(0)
    }

    ActionPanel {
        id: actionPanel
        anchors.centerIn: parent
        animDuration: root.animDuration
        onActionSelected: exitCode => root.requestClose(exitCode)
        onExitFinished: Qt.exit(root.exitCodeToReturn)
    }

    Component.onCompleted: actionPanel.startEntry()
}
