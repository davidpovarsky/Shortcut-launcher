import AppIntents
import Foundation

// Native iPadOS Shortcuts runtime UI experiment: does setting a collection
// size on a primitive array parameter change requestValue() from a generic
// picker into the native add/remove/reorder list editor?
//
// Separate discoverable intents let the user A/B test with vs without size
// on the same iPad, build, OS, and Shortcut host.

enum RuntimeTextListExperiment {
    static func resultText(_ values: [String], variant: String) -> String {
        let text = values.enumerated()
            .map { index, value in
                "\(index + 1). \(value.isEmpty ? "<empty>" : value)"
            }
            .joined(separator: "\n")

        return """
        \(variant)
        Items: \(values.count)
        \(text.isEmpty ? "(No items returned)" : text)
        """
    }
}

/// A/B case A: size constrained list. It is essential that the value is
/// collected inside perform() via requestValue(), not just configured in
/// the Shortcuts action editor.
struct RuntimeSizedTextListIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Runtime Text List (Sized)"
    static let description = IntentDescription(
        "Test native runtime list editing: request [String] with a min/max collection size."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Text items",
        description: "Experiment: add, delete and reorder text values.",
        size: .init(min: 1, max: 8)
    )
    var items: [String]?

    static var parameterSummary: some ParameterSummary {
        Summary("Request a sized text list")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let values = try await $items.requestValue(
            "הוסף פריטים לרשימה בזמן הרצת הקיצור"
        )
        return .result(
            value: RuntimeTextListExperiment.resultText(
                values,
                variant: "SIZED (1-8) / requestValue()"
            )
        )
    }
}

/// A/B case B: exactly the same primitive array and requestValue(), but no
/// @Parameter(size:). This gives a real UI baseline for the host.
struct RuntimePlainTextListIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Runtime Text List (Plain)"
    static let description = IntentDescription(
        "Control experiment: request [String] during execution, without collection size."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Text items",
        description: "Control test: unconstrained text values."
    )
    var items: [String]?

    static var parameterSummary: some ParameterSummary {
        Summary("Request an ordinary text list")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let values = try await $items.requestValue(
            "הוסף פריטים לרשימה בזמן הרצת הקיצור"
        )
        return .result(
            value: RuntimeTextListExperiment.resultText(
                values,
                variant: "PLAIN / requestValue()"
            )
        )
    }
}
