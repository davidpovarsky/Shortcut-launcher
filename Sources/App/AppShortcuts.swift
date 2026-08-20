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
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
