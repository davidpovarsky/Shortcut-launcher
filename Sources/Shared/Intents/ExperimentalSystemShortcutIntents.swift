import AppIntents

struct ExperimentalSystemShortcutConfigurationIntent:
    WidgetConfigurationIntent,
    ControlConfigurationIntent
{
    static let title: LocalizedStringResource = "LAB: System Shortcut Configuration"
    static let description = IntentDescription("Choose a System Shortcut for the Control Center experiments.")
    static let isDiscoverable: Bool = false

    @Parameter(title: "System Shortcut")
    var shortcut: SystemShortcut?

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$shortcut)")
    }

    init() {}
    init(shortcut: SystemShortcut?) { self.shortcut = shortcut }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("ExperimentalSystemShortcutConfigurationIntent.perform")
        guard let shortcut else {
            DiagnosticLog.record("systemShortcut.dual.noShortcut")
            return .result()
        }
        DiagnosticLog.record("systemShortcut.dual.beforePerform")
        do {
            _ = try await RunSystemShortcutIntent(shortcut: shortcut).perform()
            DiagnosticLog.record("systemShortcut.dual.afterPerform")
            return .result()
        } catch {
            DiagnosticLog.record("systemShortcut.dual.error", details: ["error": error.localizedDescription])
            throw error
        }
    }
}

struct ExperimentalWrappedSystemShortcutIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "LAB: Wrapped System Shortcut"
    static let description = IntentDescription("Calls RunSystemShortcutIntent.perform() from another AppIntent.")

    @Parameter(title: "System Shortcut")
    var shortcut: SystemShortcut?

    init() {}
    init(shortcut: SystemShortcut?) { self.shortcut = shortcut }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("ExperimentalWrappedSystemShortcutIntent.perform")
        guard let shortcut else {
            DiagnosticLog.record("systemShortcut.wrapped.noShortcut")
            return .result()
        }
        DiagnosticLog.record("systemShortcut.wrapped.beforePerform")
        do {
            _ = try await RunSystemShortcutIntent(shortcut: shortcut).perform()
            DiagnosticLog.record("systemShortcut.wrapped.afterPerform")
            return .result()
        } catch {
            DiagnosticLog.record("systemShortcut.wrapped.error", details: ["error": error.localizedDescription])
            throw error
        }
    }
}

struct ExperimentalMainTargetSystemShortcutIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "LAB: Main Target System Shortcut"
    static let description = IntentDescription("Calls RunSystemShortcutIntent.perform() from a main-target AppIntent.")
    static let isDiscoverable: Bool = false
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Parameter(title: "System Shortcut")
    var shortcut: SystemShortcut?

    init() {}
    init(shortcut: SystemShortcut?) { self.shortcut = shortcut }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("ExperimentalMainTargetSystemShortcutIntent.perform")
        guard let shortcut else {
            DiagnosticLog.record("systemShortcut.mainTarget.noShortcut")
            DiagnosticLog.syncSharedLogToDocuments()
            return .result()
        }
        DiagnosticLog.record("systemShortcut.mainTarget.beforePerform")
        do {
            _ = try await RunSystemShortcutIntent(shortcut: shortcut).perform()
            DiagnosticLog.record("systemShortcut.mainTarget.afterPerform")
            DiagnosticLog.syncSharedLogToDocuments()
            return .result()
        } catch {
            DiagnosticLog.record("systemShortcut.mainTarget.error", details: ["error": error.localizedDescription])
            DiagnosticLog.syncSharedLogToDocuments()
            throw error
        }
    }
}
