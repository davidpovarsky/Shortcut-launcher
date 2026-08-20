import AppIntents

struct GetLauncherStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Launcher State"
    static let description = IntentDescription("Read the current state of a launcher.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get state of \(\.$launcher)")
    }

    init() {}

    init(launcher: LauncherEntity) {
        self.launcher = launcher
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let profile = SharedLauncherStore.profile(id: launcher.id) else {
            throw LauncherError.profileNotFound
        }
        let value = profile.resolvedState().rawValue
        return .result(value: value, dialog: "\(profile.name) is \(profile.resolvedState().defaultTitle).")
    }
}
