import Foundation

struct LauncherVisualStyle: Codable, Hashable, Sendable {
    var title: String
    var symbolName: String
    var tint: LauncherTint

    init(title: String, symbolName: String, tint: LauncherTint) {
        self.title = title
        self.symbolName = symbolName
        self.tint = tint
    }
}

struct LauncherAppearance: Codable, Hashable, Sendable {
    var idle: LauncherVisualStyle
    var active: LauncherVisualStyle
    var success: LauncherVisualStyle
    var failure: LauncherVisualStyle

    func style(for state: LauncherState) -> LauncherVisualStyle {
        switch state {
        case .idle: idle
        case .active: active
        case .success: success
        case .failure: failure
        }
    }
}
