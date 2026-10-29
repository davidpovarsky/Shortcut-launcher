import AppIntents

struct DavLauncherAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWebLabIntent(), phrases: ["Start web lab with \(.applicationName)"], shortTitle: "LAB Web Server", systemImageName: "network")
        AppShortcut(intent: WebLabLogIntent(), phrases: ["Read web lab log with \(.applicationName)"], shortTitle: "LAB Web Log", systemImageName: "doc.text.magnifyingglass")
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
            intent: LabNativePersonOptionsIntent(),
            phrases: ["Search demo contacts with \(.applicationName)"],
            shortTitle: "LAB Contact Search",
            systemImageName: "person.crop.circle.badge.magnifyingglass"
        )
        AppShortcut(
            intent: SearchableRichObjectIntent(),
            phrases: ["Search demo objects with \(.applicationName)"],
            shortTitle: "LAB Search Objects",
            systemImageName: "magnifyingglass.circle"
        )
        AppShortcut(
            intent: ObjectTypeLabIntent(),
            phrases: ["Test object types with \(.applicationName)"],
            shortTitle: "LAB Object Types",
            systemImageName: "square.stack.3d.up"
        )
        AppShortcut(
            intent: ShowMixedMenuIntent(),
            phrases: ["Show mixed menu with \(.applicationName)"],
            shortTitle: "Show Mixed Menu",
            systemImageName: "list.bullet.rectangle.portrait"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
