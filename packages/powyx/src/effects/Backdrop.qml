// qmllint disable unqualified unresolved-type missing-property
import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Item {
    id: backdrop

    required property var cfg
    required property int animDuration

    signal dismissed

    Rectangle {
        id: overlay
        anchors.fill: parent
        color: backdrop.cfg.BackdropColor || Style.colors.bgDeep
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                id: opacityAnim
                duration: backdrop.animDuration * 4
                easing.type: Easing.OutQuart
            }
        }
    }

    function fadeOut() {
        opacityAnim.duration = backdrop.animDuration * 1.5;
        overlay.opacity = 0;
    }

    RadialGradient {
        anchors.fill: parent
        opacity: 0.6
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 0.6
                color: "#44000000"
            }
            GradientStop {
                position: 1.0
                color: "#AA000000"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.03
        visible: true
        color: "black"
    }

    MouseArea {
        id: dismissArea
        anchors.fill: parent
        z: -1
        onClicked: backdrop.dismissed()
    }

    Component.onCompleted: {
        overlay.opacity = parseFloat(backdrop.cfg.BackdropOpacity) || Style.effects.backdropOpacity;
    }
}
