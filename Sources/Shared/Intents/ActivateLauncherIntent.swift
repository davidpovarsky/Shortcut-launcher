import AppIntents

struct ActivateLauncherIntent: AppIntent {
    static let title: LocalizedStringResource = "Activate Launcher"
    static let description = IntentDescription("Activate a launcher and send its notification trigger.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable: Bool = false
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity

    init() {}

    init(launcher: LauncherEntity) {
        self.launcher = launcher
    }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("ActivateLauncherIntent.perform")
        DiagnosticLog.record(
            "activateIntent.enter",
            details: [
                "launcherID": launcher.id.uuidString,
                "launcherName": launcher.name,
                "sharedContainerAvailable": String(AppEnvironment.sharedContainerURL != nil)
            ]
        )

        do {
            let updated = try await LauncherCoordinator.activate(profileID: launcher.id)
            DiagnosticLog.record(
                "activateIntent.success",
                details: [
                    "launcherID": launcher.id.uuidString,
                    "state": updated.state.rawValue
                ]
            )
            DiagnosticLog.syncSharedLogToDocuments()
            return .result()
        } catch LauncherError.notificationsNotAuthorized {
            DiagnosticLog.record(
                "activateIntent.notificationsNotAuthorized",
                details: ["launcherID": launcher.id.uuidString]
            )
            LauncherReloadService.reloadAll()
            DiagnosticLog.syncSharedLogToDocuments()
            return .result()
        } catch {
            DiagnosticLog.record(
                "activateIntent.error",
                details: [
                    "launcherID": launcher.id.uuidString,
                    "error": String(describing: error),
                    "localized": error.localizedDescription
                ]
            )
            DiagnosticLog.syncSharedLogToDocuments()
            throw error
        }
    }
}
