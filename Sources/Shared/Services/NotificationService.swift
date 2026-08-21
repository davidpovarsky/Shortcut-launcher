import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async throws -> Bool {
        DiagnosticLog.record("notifications.requestAuthorization.begin")
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            DiagnosticLog.record("notifications.requestAuthorization.result", details: ["granted": String(granted)])
            return granted
        } catch {
            DiagnosticLog.record("notifications.requestAuthorization.error", details: ["error": error.localizedDescription])
            throw error
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        logSettings(settings, event: "notifications.settings")
        return settings.authorizationStatus
    }

    @discardableResult
    static func ensureAuthorization(requestIfNeeded: Bool) async throws -> UNAuthorizationStatus {
        var settings = await UNUserNotificationCenter.current().notificationSettings()
        logSettings(settings, event: "notifications.ensureAuthorization.initial")

        if settings.authorizationStatus == .notDetermined, requestIfNeeded {
            _ = try await requestAuthorization()
            settings = await UNUserNotificationCenter.current().notificationSettings()
            logSettings(settings, event: "notifications.ensureAuthorization.afterRequest")
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return settings.authorizationStatus
        case .notDetermined, .denied:
            DiagnosticLog.record(
                "notifications.ensureAuthorization.rejected",
                details: ["status": String(settings.authorizationStatus.rawValue)]
            )
            throw LauncherError.notificationsNotAuthorized
        @unknown default:
            DiagnosticLog.record("notifications.ensureAuthorization.unknownStatus")
            throw LauncherError.notificationsNotAuthorized
        }
    }

    static func send(
        profile: LauncherProfile,
        requestAuthorizationIfNeeded: Bool = false
    ) async throws {
        let config = profile.notification
        DiagnosticLog.record(
            "notifications.send.begin",
            details: [
                "profileID": profile.id.uuidString,
                "profileName": profile.name,
                "enabled": String(config.isEnabled),
                "requestAuthorizationIfNeeded": String(requestAuthorizationIfNeeded),
                "playsSound": String(config.playsSound),
                "includesAutomationToken": String(config.includesAutomationToken),
                "automationToken": config.automationToken
            ]
        )

        guard config.isEnabled else {
            DiagnosticLog.record("notifications.send.skippedDisabled", details: ["profileID": profile.id.uuidString])
            return
        }

        _ = try await ensureAuthorization(requestIfNeeded: requestAuthorizationIfNeeded)

        let content = UNMutableNotificationContent()
        content.title = config.title.isEmpty ? profile.name : config.title
        content.subtitle = config.subtitle
        content.body = config.renderedBody
        content.userInfo = [
            "launcherProfileID": profile.id.uuidString,
            "automationToken": config.automationToken
        ]
        if config.playsSound {
            content.sound = .default
        }

        let identifier = "davlauncher.\(profile.id.uuidString).\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        DiagnosticLog.record(
            "notifications.send.add.begin",
            details: [
                "identifier": identifier,
                "title": content.title,
                "subtitle": content.subtitle,
                "body": content.body
            ]
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            DiagnosticLog.record("notifications.send.add.success", details: ["identifier": identifier])
        } catch {
            DiagnosticLog.record(
                "notifications.send.add.error",
                details: [
                    "identifier": identifier,
                    "error": String(describing: error),
                    "localized": error.localizedDescription
                ]
            )
            throw error
        }
    }

    static func sendDiagnosticNotification(label: String) async throws {
        DiagnosticLog.record("notifications.diagnostic.begin", details: ["label": label])
        _ = try await ensureAuthorization(requestIfNeeded: false)

        let content = UNMutableNotificationContent()
        content.title = "Dav Launcher Diagnostic"
        content.body = "Control Center notification probe: \(label)"
        content.userInfo = ["diagnosticLabel": label]

        let identifier = "davlauncher.diagnostic.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            DiagnosticLog.record("notifications.diagnostic.success", details: ["label": label, "identifier": identifier])
        } catch {
            DiagnosticLog.record("notifications.diagnostic.error", details: ["label": label, "error": error.localizedDescription])
            throw error
        }
    }

    private static func logSettings(_ settings: UNNotificationSettings, event: String) {
        DiagnosticLog.record(
            event,
            details: [
                "authorizationStatus": String(settings.authorizationStatus.rawValue),
                "alertSetting": String(settings.alertSetting.rawValue),
                "soundSetting": String(settings.soundSetting.rawValue),
                "badgeSetting": String(settings.badgeSetting.rawValue),
                "lockScreenSetting": String(settings.lockScreenSetting.rawValue),
                "notificationCenterSetting": String(settings.notificationCenterSetting.rawValue),
                "scheduledDeliverySetting": String(settings.scheduledDeliverySetting.rawValue)
            ]
        )
    }
}
