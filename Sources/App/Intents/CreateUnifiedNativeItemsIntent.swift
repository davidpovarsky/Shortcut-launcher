import AppIntents
import Foundation

/// Make the same native objects without presenting ANY picker. Shortcuts can
/// pass the result to Choose from List, Repeat with Each, Get Details, etc.
struct CreateUnifiedNativeItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Create Unified Native Items"
    static let description = IntentDescription(
        "Convert mixed JSON into a list of native rich objects, people and menu entities without prompting."
    )
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    @Parameter(
        title: "Mixed JSON",
        description: "Array with format per item, or object with richObjects, contacts and menuItems."
    )
    var mixedJSON: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create native items from \(\.$mixedJSON)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<[UnifiedNativePickerValue]> {
        let batch = try await UnifiedNativeItemBuilder.prepare(mixedJSON)
        return .result(value: batch.values)
    }
}
