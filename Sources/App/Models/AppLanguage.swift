import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "davlauncher.appLanguage"

    case system
    case hebrew
    case english

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .hebrew:
            return Locale(identifier: "he")
        case .english:
            return Locale(identifier: "en")
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .hebrew:
            return .rightToLeft
        case .english:
            return .leftToRight
        case .system:
            return Locale.current.language.languageCode?.identifier == "he" ? .rightToLeft : .leftToRight
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "Follow System"
        case .hebrew: "Hebrew"
        case .english: "English"
        }
    }
}
