// qmllint disable unqualified unresolved-type missing-property
import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Item {
    id: actionBtn

    required property int idx
    required property string action
    required property string label
    required property string iconPath
    required property var cfg
    required property int animDuration
    required property int animEasing
    required property real staggerDelay

    signal actionFired(int exitCode)

    readonly property int btnSize: parseInt(cfg.ButtonSize) || Style.spacing.buttonSize
    readonly property int btnRadius: parseInt(cfg.ButtonRadius) || Style.spacing.buttonRadius

    property bool isHovered: mouseArea.containsMouse && !mouseArea.pressed
    property bool isPressed: mouseArea.pressed
    property bool confirming: false

    width: btnSize
    height: btnSize + (cfg.ShowLabels !== "false" ? Style.spacing.xxl : 0)

    implicitWidth: width
    implicitHeight: height

    readonly property bool needsConfirm: {
        const actions = (cfg.ConfirmActions || "reboot,shutdown").split(",").map(s => s.trim());
        return actions.indexOf(actionBtn.action) !== -1;
    }

    readonly property int exitCode: {
        switch (actionBtn.action) {
        case "lock":
            return 10;
        case "suspend":
            return 11;
        case "reboot":
            return 12;
        case "shutdown":
            return 13;
        default:
            return 0;
        }
    }

    readonly property int fastAnim: 120
    readonly property int normalAnim: animDuration || 300
    readonly property var easeCurve: Easing.OutQuart

    opacity: 0
    scale: 0.92

    SequentialAnimation {
        id: entryAnim
        running: false
        PauseAnimation {
            duration: actionBtn.staggerDelay
        }
        ParallelAnimation {
            NumberAnimation {
                target: actionBtn
                property: "opacity"
                to: 1
                duration: actionBtn.normalAnim * 1.5
                easing.type: actionBtn.easeCurve
            }
            NumberAnimation {
                target: actionBtn
                property: "scale"
                to: 1
                duration: actionBtn.normalAnim * 2
                easing.type: Easing.OutBack
            }
        }
    }

    Timer {
        id: confirmResetTimer
        interval: 3500
        onTriggered: actionBtn.confirming = false
    }

    RectangularGlow {
        id: ambientGlow
        anchors.fill: btnRect
        glowRadius: 32
        spread: 0.2
        color: actionBtn.confirming ? Style.colors.warning : Style.colors.accent
        opacity: actionBtn.isHovered ? 0.18 : 0
        cornerRadius: btnRect.radius + glowRadius

        Behavior on opacity {
            NumberAnimation {
                duration: actionBtn.normalAnim
                easing.type: actionBtn.easeCurve
            }
        }
    }

    Rectangle {
        id: btnRect
        anchors.fill: parent
        anchors.bottomMargin: actionBtn.height - actionBtn.btnSize
        radius: actionBtn.btnRadius

        color: actionBtn.isPressed ? "#1AFFFFFF" : (actionBtn.isHovered ? "#0DFFFFFF" : "transparent")
        border.width: actionBtn.isHovered ? 2 : 1
        border.color: actionBtn.confirming ? Style.colors.warning : (actionBtn.isHovered ? Style.colors.accent : "#33FFFFFF")

        scale: actionBtn.isPressed ? 0.96 : (actionBtn.isHovered ? 1.04 : 1.0)

        Behavior on color {
            ColorAnimation {
                duration: actionBtn.fastAnim
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: actionBtn.fastAnim
            }
        }
        Behavior on border.width {
            NumberAnimation {
                duration: actionBtn.fastAnim
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: actionBtn.normalAnim
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: actionBtn.isHovered ? "#20FFFFFF" : "#10FFFFFF"
            opacity: actionBtn.isHovered ? 1.0 : 0.5
        }

        Item {
            id: iconContainer
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: parent.height * 0.42

            Image {
                id: icon
                anchors.fill: parent
                source: actionBtn.iconPath
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
                visible: false
            }

            ColorOverlay {
                anchors.fill: icon
                source: icon
                color: actionBtn.confirming ? Style.colors.warning : (actionBtn.isHovered ? Style.colors.accent : "#80FFFFFF")
                Behavior on color {
                    ColorAnimation {
                        duration: actionBtn.fastAnim
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: parent.radius + 6
            color: "transparent"
            border.width: actionBtn.confirming ? 2 : 0
            border.color: Style.colors.warning
            opacity: actionBtn.confirming ? 0.6 : 0

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 2000
                loops: Animation.Infinite
                running: actionBtn.confirming
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: actionBtn.normalAnim
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (actionBtn.needsConfirm && !actionBtn.confirming) {
                    actionBtn.confirming = true;
                    confirmResetTimer.restart();
                } else {
                    actionBtn.actionFired(actionBtn.exitCode);
                }
            }
        }
    }

    Text {
        id: labelText
        visible: actionBtn.cfg.ShowLabels !== "false"
        anchors.top: btnRect.bottom
        anchors.topMargin: Style.spacing.m
        anchors.horizontalCenter: btnRect.horizontalCenter
        text: actionBtn.confirming ? "Confirm?" : actionBtn.label

        font {
            family: actionBtn.cfg.Font || Style.typography.familyMain
            pointSize: (parseInt(actionBtn.cfg.FontSize) || Style.typography.sizeM) * 0.9
            weight: (actionBtn.isHovered || actionBtn.confirming) ? Style.typography.weightDemiBold : Style.typography.weightMedium
            letterSpacing: Style.typography.letterSpacing * 1.5
        }

        color: actionBtn.confirming ? Style.colors.warning : (actionBtn.isHovered ? Style.colors.accent : "#B0FFFFFF")
        opacity: (actionBtn.isHovered || actionBtn.confirming) ? 1.0 : 0.7

        Behavior on color {
            ColorAnimation {
                duration: actionBtn.fastAnim
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: actionBtn.fastAnim
            }
        }
    }

    Component.onCompleted: entryAnim.start()
}
