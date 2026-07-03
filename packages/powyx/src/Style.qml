pragma Singleton
import QtQuick
import "tokens"

QtObject {
    readonly property Colors colors: Colors {}
    readonly property Typography typography: Typography {}
    readonly property Spacing spacing: Spacing {}
    readonly property Animations animations: Animations {}
    readonly property Effects effects: Effects {}

    readonly property string version: "2.1.0"
    readonly property string author: "ashgw"
    readonly property string systemName: "powyx-elite"
}
