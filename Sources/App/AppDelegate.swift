import CoreSpotlight
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        DiagnosticLog.syncSharedLogToDocuments()
        DiagnosticLog.recordEnvironment("application.didFinishLaunching")
        SefariaSpotlightLab.ensureIndexedIfEnabled(reason: "application.didFinishLaunching")
        DiagnosticLog.syncSharedLogToDocuments()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        DiagnosticLog.recordEnvironment("application.didBecomeActive")
        SefariaSpotlightLab.ensureIndexedIfEnabled(reason: "application.didBecomeActive")
        DiagnosticLog.syncSharedLogToDocuments()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        DiagnosticLog.record("application.didEnterBackground")
        DiagnosticLog.syncSharedLogToDocuments()
    }

    func application(
        _ application: UIApplication,
        willContinueUserActivityWithType userActivityType: String
    ) -> Bool {
        guard userActivityType == CSQueryContinuationActionType else { return false }
        DiagnosticLog.record("spotlight.searchContinuation.willContinue")
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        let handled = SpotlightSearchCoordinator.shared.receive(
            userActivity: userActivity,
            source: .appDelegate
        )
        if handled {
            restorationHandler(nil)
        }
        return handled
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
