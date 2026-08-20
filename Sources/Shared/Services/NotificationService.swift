import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func send(profile: LauncherProfile) async throws {
        let config = profile.notification
        guard config.isEnabled else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined, .denied:
            throw LauncherError.notificationsNotAuthorized
        @unknown default:
            throw LauncherError.notificationsNotAuthorized
        }

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
