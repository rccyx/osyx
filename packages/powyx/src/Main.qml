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
    readonly property color confirmColor: root.readConfirmColor()

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

    function readConfirmColor() {
        const prefix = "--confirm=";

        for (let i = 0; i < Qt.application.arguments.length; i++) {
            const arg = Qt.application.arguments[i];

            if (arg.indexOf(prefix) === 0)
                return arg.slice(prefix.length);
        }

        return Style.colors.confirm;
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
        confirmColor: root.confirmColor
        onActionSelected: exitCode => root.requestClose(exitCode)
        onExitFinished: Qt.exit(root.exitCodeToReturn)
    }

    Component.onCompleted: actionPanel.startEntry()
}
