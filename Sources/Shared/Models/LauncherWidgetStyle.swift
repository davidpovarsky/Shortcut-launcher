import AppIntents
import Foundation

enum LauncherWidgetStyle: String, Codable, CaseIterable, Hashable, Sendable, AppEnum {
    case glass
    case cards
    case minimal
    case vibrant

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Widget style"

    static let caseDisplayRepresentations: [LauncherWidgetStyle: DisplayRepresentation] = [
        .glass: "Glass",
        .cards: "Cards",
        .minimal: "Minimal",
        .vibrant: "Vibrant"
    ]

    var title: String {
        switch self {
        case .glass: "Glass"
        case .cards: "Cards"
        case .minimal: "Minimal"
        case .vibrant: "Vibrant"
        }
    }

    var symbolName: String {
        switch self {
        case .glass: "square.on.square"
        case .cards: "rectangle.grid.2x2"
        case .minimal: "circle.grid.2x2"
        case .vibrant: "paintpalette.fill"
        }
    }
}
