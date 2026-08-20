import Foundation

struct LauncherNotification: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var title: String
    var subtitle: String
    var body: String
    var automationToken: String
    var includesAutomationToken: Bool
    var playsSound: Bool

    init(
        isEnabled: Bool = true,
        title: String = "Dav Launcher",
        subtitle: String = "",
        body: String = "Automation trigger",
        automationToken: String = "DAV:DEFAULT",
        includesAutomationToken: Bool = true,
        playsSound: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.automationToken = automationToken
        self.includesAutomationToken = includesAutomationToken
        self.playsSound = playsSound
    }

    var renderedBody: String {
        guard includesAutomationToken, !automationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return body
        }
        if body.isEmpty {
            return "[\(automationToken)]"
        }
        return "\(body) [\(automationToken)]"
    }
}
