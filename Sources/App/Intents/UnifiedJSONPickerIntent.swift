import AppIntents
import Foundation

/// Choose one of three genuinely different native App Intents value types.
/// The JSON is only an input source; the output is NOT a JSON string.
struct UnifiedJSONPickerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Unified JSON Picker"
    static let description = IntentDescription(
        "Choose a native rich object, person, or menu entity supplied by JSON; return the typed item."
    )
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    @Parameter(
        title: "Mixed JSON",
        description: "Array with format per item, or object with richObjects, contacts and menuItems."
    )
    var mixedJSON: String

    // Runtime selection, rather than prompting while authoring the shortcut.
    @Parameter(title: "Selected Item")
    var selectedItem: UnifiedNativePickerValue?

    static var parameterSummary: some ParameterSummary {
        Summary("Choose a native item from \(\.$mixedJSON)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<UnifiedNativePickerValue> {
        let batch = try await UnifiedNativeItemBuilder.prepare(mixedJSON)
        let chosen = try await $selectedItem.requestDisambiguation(
            among: batch.values,
            dialog: "Choose a rich object, contact, or menu item"
        )
        guard batch.index(of: chosen) != nil else {
            throw UnifiedPickerError.missingSelection
        }
        return .result(value: chosen)
    }
}
