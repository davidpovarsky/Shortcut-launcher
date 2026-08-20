import AppIntents
import Foundation

enum LauncherTint: String, Codable, CaseIterable, Hashable, Sendable, AppEnum {
    case gray
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Launcher color"

    static let caseDisplayRepresentations: [LauncherTint: DisplayRepresentation] = [
        .gray: "Gray",
        .blue: "Blue",
        .indigo: "Indigo",
        .purple: "Purple",
        .pink: "Pink",
        .red: "Red",
        .orange: "Orange",
        .yellow: "Yellow",
        .green: "Green",
        .mint: "Mint",
        .teal: "Teal",
        .cyan: "Cyan"
    ]
}
