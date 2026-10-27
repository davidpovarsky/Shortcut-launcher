import AppIntents
import Foundation
import UIKit

/// Transient entity used only for one runtime picker. It is never inserted into
/// a user's contacts: "vcard" is a card-style row, not a Contacts write.
struct MixedMenuChoiceEntity: AppEntity, Hashable, Codable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mixed Menu Item")
    static let defaultQuery = MixedMenuChoiceQuery()

    let id: String
    let title: String
    let subtitle: String
    let type: String
    let imageData: Data?

    var displayRepresentation: DisplayRepresentation {
        let image: DisplayRepresentation.Image
        if let imageData {
            image = DisplayRepresentation.Image(
                data: imageData,
                isTemplate: false,
                displayStyle: .default
            )
        } else {
            image = DisplayRepresentation.Image(systemName: "square.grid.2x2.fill", isTemplate: true)
        }
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)",
            image: image
        )
    }
}

struct MixedMenuChoiceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MixedMenuChoiceEntity] {
        MixedMenuChoiceStore.resolve(identifiers)
    }

    func suggestedEntities() async throws -> [MixedMenuChoiceEntity] {
        // These menu options exist only during their parent App Intent execution.
        []
    }
}

enum MixedMenuChoiceStore {
    private static let prefix = "mixedMenu.runtime."
    private static let lifetime: TimeInterval = 60 * 60

    private struct Snapshot: Codable {
        let created: Date
        let entities: [MixedMenuChoiceEntity]
    }

    static func save(_ entities: [MixedMenuChoiceEntity], session: String) throws {
        let defaults = AppEnvironment.sharedDefaults
        removeExpired(from: defaults)
        let snapshot = Snapshot(created: Date(), entities: entities)
        defaults.set(try JSONEncoder().encode(snapshot), forKey: prefix + session)
    }

    static func resolve(_ identifiers: [String]) -> [MixedMenuChoiceEntity] {
        let defaults = AppEnvironment.sharedDefaults
        let sessions = Set(identifiers.compactMap { $0.split(separator: ":", maxSplits: 1).first.map(String.init) })
        var found: [String: MixedMenuChoiceEntity] = [:]
        for session in sessions {
            guard let data = defaults.data(forKey: prefix + session),
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
                  Date().timeIntervalSince(snapshot.created) <= lifetime else {
                continue
            }
            for entity in snapshot.entities {
                found[entity.id] = entity
            }
        }
        return identifiers.compactMap { found[$0] }
    }

    static func remove(session: String) {
        AppEnvironment.sharedDefaults.removeObject(forKey: prefix + session)
    }

    private static func removeExpired(from defaults: UserDefaults) {
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            guard let data = value as? Data,
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
                  Date().timeIntervalSince(snapshot.created) <= lifetime else {
                defaults.removeObject(forKey: key)
                continue
            }
        }
    }
}

@MainActor
enum MixedMenuIconRenderer {
    static func image(for item: MixedMenuItem) -> Data? {
        if let encoded = item.imageBase64,
           let data = Data(base64Encoded: encoded),
           UIImage(data: data) != nil {
            return data
        }

        let foreground = color(item.color)
        let background = item.backgroundColor.map(color)
            ?? foreground.withAlphaComponent(item.type == "rich" ? 0.16 : 0.22)
        let size = CGSize(width: 96, height: 96)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.pngData { _ in
            let bounds = CGRect(origin: .zero, size: size)
            let radius: CGFloat = item.type == "rich" ? 48 : 19
            background.setFill()
            UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: radius).fill()

            let config = UIImage.SymbolConfiguration(pointSize: 46, weight: .medium)
            let symbol = UIImage(systemName: item.icon, withConfiguration: config)
                ?? UIImage(systemName: "square.grid.2x2.fill", withConfiguration: config)
            guard let symbol else { return }
            let aspect = symbol.size.width / max(symbol.size.height, 1)
            let maxDimension: CGFloat = 51
            let drawSize = CGSize(
                width: aspect >= 1 ? maxDimension : maxDimension * aspect,
                height: aspect >= 1 ? maxDimension / aspect : maxDimension
            )
            let iconRect = CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            symbol.withTintColor(foreground, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
    }

    private static func color(_ hex: String) -> UIColor {
        let bytes = String(hex.dropFirst())
        let value = UInt64(bytes, radix: 16) ?? 0
        let hasAlpha = bytes.count == 8
        let red = hasAlpha ? (value >> 24) & 0xFF : (value >> 16) & 0xFF
        let green = hasAlpha ? (value >> 16) & 0xFF : (value >> 8) & 0xFF
        let blue = hasAlpha ? (value >> 8) & 0xFF : value & 0xFF
        let alpha: UInt64 = hasAlpha ? value & 0xFF : 255
        return UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}

/// One App Intent: JSON input -> system picker -> exact selected JSON output.
struct ShowMixedMenuIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Mixed Menu"
    static let description = IntentDescription(
        "Show a system picker from JSON with rich and card-style rows, and return the selected item's JSON."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Menu JSON", description: "JSON array or object with title, subtitle, icon, color and optional type.")
    var menuJSON: String

    // Optional so the picker is requested by perform(), not while editing the Shortcut.
    @Parameter(title: "Selected Item")
    var selectedItem: MixedMenuChoiceEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Choose an item from \(.$menuJSON)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let items = try MixedMenuParser.parse(menuJSON)
        let session = UUID().uuidString
        let choices = await MainActor.run {
            items.enumerated().map { index, item in
                MixedMenuChoiceEntity(
                    id: "\(session):\(index)",
                    title: item.title,
                    subtitle: item.subtitle,
                    type: item.type,
                    imageData: MixedMenuIconRenderer.image(for: item)
                )
            }
        }
        try MixedMenuChoiceStore.save(choices, session: session)
        defer { MixedMenuChoiceStore.remove(session: session) }

        // The OS presents this native selection *inside* the running action.
        // Let cancellation throw naturally rather than treating it as a choice.
        let selected = try await $selectedItem.requestDisambiguation(
            among: choices,
            dialog: "בחר פריט מהרשימה"
        )
        guard let index = choices.firstIndex(where: { $0.id == selected.id }) else {
            throw MixedMenuInputError.invalidJSON
        }
        return .result(value: items[index].rawJSON)
    }
}
