import AppIntents
import Foundation

/// Diagnostic bridge for the new system compose Share/Action extensions.
/// Returns a JSON manifest with text, source and relative attachment names.
/// The actual files remain in the shared App Group container for the app's
/// agent to consume. Nothing is uploaded automatically.
struct ReadLastAIComposeDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Last AI Compose Draft"
    static let description = IntentDescription(
        "Read the last message and attachment manifest saved by the Dav AI Compose Share or Action extension."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: AIComposeDraftStore.lastDraftJSONString())
    }
}
