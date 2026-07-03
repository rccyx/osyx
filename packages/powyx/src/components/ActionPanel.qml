import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: panel

    required property var cfg
    required property int animDuration

    signal actionSelected(int exitCode)
    signal exitFinished

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
            to: 1.0
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
            spacing: parseInt(panel.cfg.ButtonSpacing) || Style.spacing.buttonGap

            ActionButton {
                idx: 0
                action: "lock"
                label: "Lock"
                iconPath: Qt.resolvedUrl("../../icons/lock.svg")
                cfg: panel.cfg
                animDuration: panel.animDuration
                animEasing: Easing.OutQuart
                staggerDelay: 0 * 60
                onActionFired: exitCode => panel.actionSelected(exitCode)
            }

            ActionButton {
                idx: 1
                action: "suspend"
                label: "Suspend"
                iconPath: Qt.resolvedUrl("../../icons/sleep.svg")
                cfg: panel.cfg
                animDuration: panel.animDuration
                animEasing: Easing.OutQuart
                staggerDelay: 1 * 60
                onActionFired: exitCode => panel.actionSelected(exitCode)
            }

            ActionButton {
                idx: 2
                action: "reboot"
                label: "Reboot"
                iconPath: Qt.resolvedUrl("../../icons/restart.svg")
                cfg: panel.cfg
                animDuration: panel.animDuration
                animEasing: Easing.OutQuart
                staggerDelay: 2 * 60
                onActionFired: exitCode => panel.actionSelected(exitCode)
            }

            ActionButton {
                idx: 3
                action: "shutdown"
                label: "Shutdown"
                iconPath: Qt.resolvedUrl("../../icons/shutdown.svg")
                cfg: panel.cfg
                animDuration: panel.animDuration
                animEasing: Easing.OutQuart
                staggerDelay: 3 * 60
                onActionFired: exitCode => panel.actionSelected(exitCode)
            }
        }
    }
}
