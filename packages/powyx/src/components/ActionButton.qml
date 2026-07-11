import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Item {
    id: actionBtn

    required property string action
    required property string label
    required property url iconSource
    required property color confirmColor

    property int idx: 0
    property int animDuration: Style.animations.normal
    property real staggerDelay: 0
    property bool hovered: mouseArea.containsMouse && !mouseArea.pressed
    property bool pressed: mouseArea.pressed
    property bool confirming: false

    signal actionFired(int exitCode)

    readonly property int btnSize: Style.spacing.buttonSize
    readonly property int btnRadius: Style.spacing.buttonRadius
    readonly property int fastAnim: Style.animations.fast
    readonly property int normalAnim: animDuration
    readonly property var easeCurve: Easing.OutQuart

    width: btnSize
    height: btnSize + Style.spacing.xxl

    implicitWidth: width
    implicitHeight: height

    function exitCode() {
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

    function requiresConfirmation() {
        return actionBtn.action === "reboot" || actionBtn.action === "shutdown";
    }

    function activate() {
        if (actionBtn.requiresConfirmation() && !actionBtn.confirming) {
            actionBtn.confirming = true;
            confirmResetTimer.restart();
            return;
        }

        actionBtn.actionFired(actionBtn.exitCode());
    }

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
        color: actionBtn.confirming ? actionBtn.confirmColor : Style.colors.accent
        opacity: actionBtn.hovered ? 0.18 : 0
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

        color: actionBtn.pressed ? Style.colors.surfacePressed : actionBtn.hovered ? Style.colors.surfaceHover : Style.colors.transparent
        border.width: actionBtn.hovered ? 2 : 1
        border.color: actionBtn.confirming ? actionBtn.confirmColor : actionBtn.hovered ? Style.colors.accent : Style.colors.borderGlass

        scale: actionBtn.pressed ? 0.96 : actionBtn.hovered ? 1.04 : 1

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
            color: Style.colors.transparent
            border.width: 1
            border.color: actionBtn.hovered ? Style.colors.innerBorderHover : Style.colors.innerBorder
            opacity: actionBtn.hovered ? 1 : 0.5
        }

        Item {
            id: iconContainer
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: parent.height * 0.42

            Image {
                id: icon
                anchors.fill: parent
                source: actionBtn.iconSource
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
                color: actionBtn.confirming ? actionBtn.confirmColor : actionBtn.hovered ? Style.colors.accent : Style.colors.iconMuted
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
            color: Style.colors.transparent
            border.width: actionBtn.confirming ? 2 : 0
            border.color: actionBtn.confirming ? actionBtn.confirmColor : Style.colors.transparent
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
            onClicked: actionBtn.activate()
        }
    }

    Text {
        id: labelText
        anchors.top: btnRect.bottom
        anchors.topMargin: Style.spacing.m
        anchors.horizontalCenter: btnRect.horizontalCenter
        text: actionBtn.confirming ? "Confirm?" : actionBtn.label

        font {
            family: Style.typography.familyMain
            pointSize: Style.typography.sizeM * 0.9
            weight: actionBtn.hovered || actionBtn.confirming ? Style.typography.weightDemiBold : Style.typography.weightMedium
            letterSpacing: Style.typography.letterSpacing * 1.5
        }

        color: actionBtn.confirming ? actionBtn.confirmColor : actionBtn.hovered ? Style.colors.accent : Style.colors.labelMuted
        opacity: actionBtn.hovered || actionBtn.confirming ? 1 : 0.7

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
