import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        DiagnosticLog.syncSharedLogToDocuments()
        DiagnosticLog.recordEnvironment("application.didFinishLaunching")
        DiagnosticLog.syncSharedLogToDocuments()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        DiagnosticLog.recordEnvironment("application.didBecomeActive")
        DiagnosticLog.syncSharedLogToDocuments()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        DiagnosticLog.record("application.didEnterBackground")
        DiagnosticLog.syncSharedLogToDocuments()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        DiagnosticLog.record(
            "notifications.willPresent",
            details: [
                "identifier": notification.request.identifier,
                "title": notification.request.content.title,
                "body": notification.request.content.body
            ]
        )
        return [.banner, .list, .sound]
    }
}
