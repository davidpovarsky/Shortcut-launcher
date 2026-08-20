import Foundation

enum LauncherState: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case active
    case success
    case failure

    var defaultTitle: String {
        switch self {
        case .idle: "Idle"
        case .active: "Active"
        case .success: "Success"
        case .failure: "Error"
        }
    }
}
