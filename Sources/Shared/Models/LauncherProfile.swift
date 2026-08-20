import Foundation

struct LauncherProfile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var appearance: LauncherAppearance
    var notification: LauncherNotification
    var state: LauncherState
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        appearance: LauncherAppearance,
        notification: LauncherNotification,
        state: LauncherState = .idle,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.appearance = appearance
        self.notification = notification
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func resolvedState() -> LauncherState {
        state
    }

    func resolvedStyle() -> LauncherVisualStyle {
        appearance.style(for: state)
    }

    mutating func setState(_ newState: LauncherState, now: Date = .now) {
        state = newState
        updatedAt = now
    }
}

extension LauncherProfile {
    static func sampleReading() -> LauncherProfile {
        LauncherProfile(
            name: "Reading Mode",
            appearance: LauncherAppearance(
                idle: .init(title: "Reading", symbolName: "book.closed", tint: .gray),
                active: .init(title: "Reading active", symbolName: "book.fill", tint: .orange),
                success: .init(title: "Ready", symbolName: "checkmark.circle.fill", tint: .green),
                failure: .init(title: "Failed", symbolName: "exclamationmark.triangle.fill", tint: .red)
            ),
            notification: LauncherNotification(
                isEnabled: true,
                title: "Reading Mode",
                subtitle: "",
                body: "Run reading automation",
                automationToken: "DAV:READING",
                includesAutomationToken: true,
                playsSound: false
            )
        )
    }

    static func sampleLights() -> LauncherProfile {
        LauncherProfile(
            name: "Lights",
            appearance: LauncherAppearance(
                idle: .init(title: "Lights", symbolName: "lightbulb", tint: .gray),
                active: .init(title: "Lights on", symbolName: "lightbulb.fill", tint: .yellow),
                success: .init(title: "Done", symbolName: "checkmark.circle.fill", tint: .green),
                failure: .init(title: "Failed", symbolName: "xmark.circle.fill", tint: .red)
            ),
            notification: LauncherNotification(
                isEnabled: true,
                title: "Lights",
                subtitle: "",
                body: "Run lights automation",
                automationToken: "DAV:LIGHTS",
                includesAutomationToken: true,
                playsSound: false
            )
        )
    }
}
