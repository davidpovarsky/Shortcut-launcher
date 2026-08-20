import AppIntents

struct SetLauncherStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Launcher State"
    static let description = IntentDescription("Change the persistent visual state of a launcher control and widget.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    @Parameter(title: "State", default: .idle)
    var state: LauncherState

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$launcher) to \(\.$state)")
    }

    init() {}

    init(launcher: LauncherEntity, state: LauncherState) {
        self.launcher = launcher
        self.state = state
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let updated = try LauncherCoordinator.setState(
            profileID: launcher.id,
            state: state
        )
        return .result(dialog: "\(updated.name) is now \(updated.resolvedState().defaultTitle).")
    }
}
