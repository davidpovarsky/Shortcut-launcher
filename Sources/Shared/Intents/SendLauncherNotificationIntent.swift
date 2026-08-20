import AppIntents

struct SendLauncherNotificationIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Launcher Notification"
    static let description = IntentDescription("Send a configured local notification that can trigger a Notification Automation in Shortcuts.")
    static let supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    @Parameter(title: "Mark active", default: true)
    var markActive: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Send notification for \(\.$launcher)")
    }

    init() {}

    init(launcher: LauncherEntity, markActive: Bool = true) {
        self.launcher = launcher
        self.markActive = markActive
    }

    func perform() async throws -> some IntentResult {
        try await LauncherCoordinator.sendNotification(profileID: launcher.id, markActive: markActive)
        return .result()
    }
}
