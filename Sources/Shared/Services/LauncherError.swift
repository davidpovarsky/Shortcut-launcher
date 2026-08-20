import Foundation

enum LauncherError: LocalizedError {
    case profileNotFound
    case notificationsNotAuthorized

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            "Launcher profile was not found."
        case .notificationsNotAuthorized:
            "Notifications are not authorized for Dav Launcher. Open the app and enable notifications first."
        }
    }
}
