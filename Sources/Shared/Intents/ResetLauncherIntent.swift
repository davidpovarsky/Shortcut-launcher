import AppIntents

struct ResetLauncherIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset Launcher"
    static let description = IntentDescription("Return a launcher to its idle appearance.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Reset \(\.$launcher)")
    }

    init() {}

    init(launcher: LauncherEntity) {
        self.launcher = launcher
    }

    func perform() async throws -> some IntentResult {
        _ = try LauncherCoordinator.setState(profileID: launcher.id, state: .idle)
        return .result()
    }
}
