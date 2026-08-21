import AppIntents

struct DiagnosticWidgetPingIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Widget Ping"
    static let description = IntentDescription("Records a diagnostic event from the WidgetKit extension.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable: Bool = false
    static var allowedExecutionTargets: IntentExecutionTargets { .widgetKitExtension }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("DiagnosticWidgetPingIntent.perform")
        DiagnosticLog.record("diagnostic.widgetPing.success")
        return .result()
    }
}

struct DiagnosticMainPingIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Main Ping"
    static let description = IntentDescription("Records a diagnostic event from the main app process.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable: Bool = false
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("DiagnosticMainPingIntent.perform")
        DiagnosticLog.record("diagnostic.mainPing.success")
        DiagnosticLog.syncSharedLogToDocuments()
        return .result()
    }
}

struct DiagnosticWidgetNotificationIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Widget Notification"
    static let description = IntentDescription("Schedules a fixed diagnostic notification from the WidgetKit extension.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable: Bool = false
    static var allowedExecutionTargets: IntentExecutionTargets { .widgetKitExtension }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("DiagnosticWidgetNotificationIntent.perform")
        do {
            try await NotificationService.sendDiagnosticNotification(label: "widgetKitExtension")
            DiagnosticLog.record("diagnostic.widgetNotification.success")
            return .result()
        } catch {
            DiagnosticLog.record("diagnostic.widgetNotification.error", details: ["error": error.localizedDescription])
            throw error
        }
    }
}

struct DiagnosticMainNotificationIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Main Notification"
    static let description = IntentDescription("Schedules a fixed diagnostic notification from the main app process.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable: Bool = false
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    func perform() async throws -> some IntentResult {
        DiagnosticLog.recordEnvironment("DiagnosticMainNotificationIntent.perform")
        do {
            try await NotificationService.sendDiagnosticNotification(label: "main")
            DiagnosticLog.record("diagnostic.mainNotification.success")
            DiagnosticLog.syncSharedLogToDocuments()
            return .result()
        } catch {
            DiagnosticLog.record("diagnostic.mainNotification.error", details: ["error": error.localizedDescription])
            DiagnosticLog.syncSharedLogToDocuments()
            throw error
        }
    }
}
