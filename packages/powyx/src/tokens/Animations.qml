import QtQuick

QtObject {
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 400
    readonly property int entrance: 600

    readonly property int easeCurve: Easing.OutQuint
    readonly property int easeBack: Easing.OutBack
}
