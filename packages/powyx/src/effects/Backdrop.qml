import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Item {
    id: backdrop

    required property int animDuration

    signal dismissed

    Rectangle {
        id: overlay
        anchors.fill: parent
        color: Style.colors.bgDeep
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
                position: 0
                color: Style.colors.transparent
            }
            GradientStop {
                position: 0.6
                color: Style.colors.vignetteMid
            }
            GradientStop {
                position: 1
                color: Style.colors.vignetteEdge
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.03
        visible: true
        color: Style.colors.black
    }

    MouseArea {
        id: dismissArea
        anchors.fill: parent
        z: -1
    }

    Component.onCompleted: overlay.opacity = Style.effects.backdropOpacity
}
