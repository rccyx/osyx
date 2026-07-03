pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: panel

    required property int animDuration

    signal actionSelected(int exitCode)
    signal exitFinished

    readonly property var actions: [
        {
            action: "lock",
            label: "Lock",
            icon: Qt.resolvedUrl("../../icons/lock.svg")
        },
        {
            action: "suspend",
            label: "Suspend",
            icon: Qt.resolvedUrl("../../icons/sleep.svg")
        },
        {
            action: "reboot",
            label: "Reboot",
            icon: Qt.resolvedUrl("../../icons/restart.svg")
        },
        {
            action: "shutdown",
            label: "Shutdown",
            icon: Qt.resolvedUrl("../../icons/shutdown.svg")
        }
    ]

    width: buttonRow.implicitWidth
    height: buttonRow.implicitHeight
    opacity: 0
    scale: 0.94

    function startEntry() {
        entryAnim.start();
    }

    function startExit() {
        exitAnim.start();
    }

    ParallelAnimation {
        id: entryAnim
        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: panel.animDuration * 2
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.94
            to: 1
            duration: panel.animDuration * 2.5
            easing.type: Easing.OutBack
        }
    }

    ParallelAnimation {
        id: exitAnim
        onFinished: panel.exitFinished()
        NumberAnimation {
            target: panel
            property: "opacity"
            to: 0
            duration: panel.animDuration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            to: 0.94
            duration: panel.animDuration
            easing.type: Easing.InCubic
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.spacing.xxl

        RowLayout {
            id: buttonRow
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.spacing.buttonGap

            Repeater {
                model: panel.actions

                ActionButton {
                    required property int index
                    required property var modelData

                    idx: index
                    action: modelData.action
                    label: modelData.label
                    iconSource: modelData.icon
                    animDuration: panel.animDuration
                    staggerDelay: index * 60
                    onActionFired: exitCode => panel.actionSelected(exitCode)
                }
            }
        }
    }
}
