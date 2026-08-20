import AppIntents

struct ActivateLauncherIntent: AppIntent {
    static let title: LocalizedStringResource = "Activate Launcher"
    static let description = IntentDescription("Activate a launcher and send its notification trigger.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable: Bool = false

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    init() {}

    init(launcher: LauncherEntity) {
        self.launcher = launcher
    }

    func perform() async throws -> some IntentResult {
        _ = try await LauncherCoordinator.activate(profileID: launcher.id)
        return .result()
    }
}
