pragma Singleton
import QtQuick
import "tokens"

QtObject {
    readonly property Colors colors: Colors {}
    readonly property Typography typography: Typography {}
    readonly property Spacing spacing: Spacing {}
    readonly property Animations animations: Animations {}
    readonly property Effects effects: Effects {}
}
