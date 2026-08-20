import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func ensureAuthorization(requestIfNeeded: Bool) async throws -> UNAuthorizationStatus {
        var status = await authorizationStatus()

        if status == .notDetermined, requestIfNeeded {
            _ = try await requestAuthorization()
            status = await authorizationStatus()
        }

        switch status {
        case .authorized, .provisional, .ephemeral:
            return status
        case .notDetermined, .denied:
            throw LauncherError.notificationsNotAuthorized
        @unknown default:
            throw LauncherError.notificationsNotAuthorized
        }
    }

    static func send(
        profile: LauncherProfile,
        requestAuthorizationIfNeeded: Bool = false
    ) async throws {
        let config = profile.notification
        guard config.isEnabled else { return }

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

        let request = UNNotificationRequest(
            identifier: "davlauncher.\(profile.id.uuidString).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(request)
    }
}
