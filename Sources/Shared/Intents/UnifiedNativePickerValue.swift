import AppIntents
import Foundation

/// A real, typed union. Unlike the previous all-MixedMenuChoiceEntity
/// representation, each selection has a different underlying App Intents type.
@UnionValue
enum UnifiedNativePickerValue {
    case rich(UnifiedRichObjectEntity)
    case contact(IntentPerson)
    case menu(MixedMenuChoiceEntity)
}

extension UnifiedNativePickerValue {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Mixed Native Picker Item"
    }

    static let caseDisplayRepresentations: [Cases: DisplayRepresentation] = [
        .rich: "Rich Object",
        .contact: "Contact",
        .menu: "Menu Item"
    ]
}

/// Rich objects have their own AppEntity type, title, description, and image.
/// Menu entries use the pre-existing MixedMenuChoiceEntity. This allows the
/// system to distinguish formats instead of displaying every row as a menu.
struct UnifiedRichObjectEntity: AppEntity, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rich Object")
    static let defaultQuery = UnifiedRichObjectQuery()

    let id: String
    let name: String
    let subtitle: String
    let iconPNG: Data

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(subtitle)",
            image: DisplayRepresentation.Image(
                data: iconPNG,
                isTemplate: false,
                displayStyle: .default
            )
        )
    }

    init(id: String, name: String, subtitle: String, iconPNG: Data) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.iconPNG = iconPNG
    }

    init(menuEntry: MixedMenuChoiceEntity) {
        self.init(
            id: menuEntry.id,
            name: menuEntry.title,
            subtitle: menuEntry.subtitle,
            iconPNG: menuEntry.imageData ?? Data()
        )
    }
}

struct UnifiedRichObjectQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [UnifiedRichObjectEntity] {
        MixedMenuChoiceStore.resolve(identifiers).map(UnifiedRichObjectEntity.init(menuEntry:))
    }

    func suggestedEntities() async throws -> [UnifiedRichObjectEntity] {
        // These items are JSON-provided per execution, not global catalog items.
        []
    }
}
