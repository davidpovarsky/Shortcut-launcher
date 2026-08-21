import AppIntents

struct DavLauncherAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetLauncherStateIntent(),
            phrases: ["Set a launcher state with \(.applicationName)"],
            shortTitle: "Set Launcher State",
            systemImageName: "switch.2"
        )
        AppShortcut(
            intent: ResetLauncherIntent(),
            phrases: ["Reset a launcher with \(.applicationName)"],
            shortTitle: "Reset Launcher",
            systemImageName: "arrow.counterclockwise"
        )
        AppShortcut(
            intent: SendLauncherNotificationIntent(),
            phrases: ["Send a launcher notification with \(.applicationName)"],
            shortTitle: "Send Notification",
            systemImageName: "bell.fill"
        )
        AppShortcut(
            intent: GetLauncherStateIntent(),
            phrases: ["Get a launcher state with \(.applicationName)"],
            shortTitle: "Get Launcher State",
            systemImageName: "questionmark.circle"
        )
        AppShortcut(
            intent: ExperimentalDurationPickerIntent(),
            phrases: ["Test duration picker with \(.applicationName)"],
            shortTitle: "LAB Duration Picker",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: ExperimentalRichEntityPickerIntent(),
            phrases: ["Test rich picker with \(.applicationName)"],
            shortTitle: "LAB Rich Picker",
            systemImageName: "square.grid.2x2"
        )
        AppShortcut(
            intent: ExperimentalRuntimeRequestValueIntent(),
            phrases: ["Test runtime prompt with \(.applicationName)"],
            shortTitle: "LAB Runtime Prompt",
            systemImageName: "text.cursor"
        )
        AppShortcut(
            intent: ExperimentalRuntimeDisambiguationIntent(),
            phrases: ["Test disambiguation with \(.applicationName)"],
            shortTitle: "LAB Disambiguation",
            systemImageName: "list.bullet.rectangle"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
