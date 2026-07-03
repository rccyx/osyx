// qmllint disable unqualified unresolved-type missing-property
import QtQuick
import QtCore

import "."
import "components"
import "effects"
import "js/Config.js" as ConfigLoader

Window {
    id: root

    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "powyx"

    property var cfg: ({})
    property int exitCodeToReturn: 0
    readonly property int animDuration: parseInt(cfg.AnimationDuration) || 300

    function loadConfig() {
        const path = ConfigLoader.resolveConfigPath(Qt.application.arguments, StandardPaths);
        const userCfg = ConfigLoader.loadTheme(path);

        const defaults = {
            Font: Style.typography.familyMain,
            FontSize: Style.typography.sizeM.toString(),
            BackdropColor: Style.colors.bgDeep,
            BackdropOpacity: Style.effects.backdropOpacity.toString(),
            ButtonBackgroundColor: Style.colors.bgSurface,
            ButtonHoverColor: Style.colors.bgElevated,
            ButtonPressColor: Style.colors.bgDeep,
            ButtonBorderColor: Style.colors.borderMed,
            ButtonHoverBorderColor: Style.colors.borderHigh,
            IconColor: Style.colors.accentMuted,
            IconHoverColor: Style.colors.accent,
            LabelColor: Style.colors.accentMuted,
            LabelHoverColor: Style.colors.accent,
            HintColor: Style.colors.borderHigh,
            AnimationDuration: "300",
            AnimationEasing: "OutQuart",
            ButtonSize: Style.spacing.buttonSize.toString(),
            ButtonSpacing: Style.spacing.buttonGap.toString(),
            ButtonRadius: Style.spacing.buttonRadius.toString(),
            ShowLabels: "true",
            ShowHint: "true",
            ConfirmActions: "reboot,shutdown"
        };

        return Object.assign({}, defaults, userCfg);
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    function closeRequested() {
        actionPanel.startExit();
        backdrop.fadeOut();
    }

    Backdrop {
        id: backdrop
        anchors.fill: parent
        cfg: root.cfg
        animDuration: root.animDuration
        onDismissed: root.closeRequested()
    }

    ActionPanel {
        id: actionPanel
        anchors.centerIn: parent
        cfg: root.cfg
        animDuration: root.animDuration
        onActionSelected: exitCode => {
            root.exitCodeToReturn = exitCode;
            root.closeRequested();
        }
        onExitFinished: Qt.exit(root.exitCodeToReturn)
    }

    Component.onCompleted: {
        root.cfg = loadConfig();
        actionPanel.startEntry();
    }

    onClosing: close => Qt.exit(root.exitCodeToReturn)
}
