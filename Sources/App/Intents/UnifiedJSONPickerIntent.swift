import AppIntents
import Foundation

/// The same Shortcuts-native runtime selector for all supported JSON formats.
/// Its rows are homogeneous AppEntities for presentation; the result contains
/// the complete source JSON item, not a fabricated Contacts record.
struct UnifiedJSONPickerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Unified JSON Picker"
    static let description = IntentDescription(
        "Select one item from mixed rich objects, demo contacts and menu entries supplied as JSON."
    )
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    @Parameter(
        title: "Mixed JSON",
        description: "Array with format per item, or object with richObjects, contacts and menuItems."
    )
    var mixedJSON: String

    // Optional: invoke the system picker at runtime rather than require an
    // editor-time parameter picker before the JSON input is available.
    @Parameter(title: "Selected Item")
    var selectedItem: MixedMenuChoiceEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Choose from mixed JSON \(.$mixedJSON)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let entries = try UnifiedPickerParser.parse(mixedJSON)
        let session = UUID().uuidString
        let choices = await MainActor.run {
            entries.enumerated().map { index, entry in
                MixedMenuChoiceEntity(
                    id: "\(session):\(index)",
                    title: entry.appearance.title,
                    subtitle: entry.appearance.subtitle,
                    type: entry.appearance.type,
                    imageData: MixedMenuIconRenderer.image(for: entry.appearance)
                )
            }
        }
        try MixedMenuChoiceStore.save(choices, session: session)
        defer { MixedMenuChoiceStore.remove(session: session) }

        // Shortcuts owns the presentation. It may omit runtime text search;
        // this action never promises native Contacts' special picker UI.
        let chosen = try await $selectedItem.requestDisambiguation(
            among: choices,
            dialog: "Choose an item from the mixed list"
        )
        guard let selectedIndex = choices.firstIndex(where: { $0.id == chosen.id }) else {
            throw UnifiedPickerError.missingSelection
        }
        return .result(value: entries[selectedIndex].outputJSON)
    }
}
