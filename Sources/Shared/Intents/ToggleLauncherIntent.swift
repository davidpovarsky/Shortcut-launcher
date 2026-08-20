import AppIntents

struct ToggleLauncherIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Launcher State"
    static let description = IntentDescription("Toggle a launcher between idle and active.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle \(\.$launcher)")
    }

    init() {}

    init(launcher: LauncherEntity) {
        self.launcher = launcher
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let updated = try LauncherCoordinator.toggle(profileID: launcher.id)
        return .result(dialog: "\(updated.name) is now \(updated.resolvedState().defaultTitle).")
    }
}
