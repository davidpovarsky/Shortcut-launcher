import AppIntents
import Foundation

// iPadOS 27 lab: the system's runtime prompt is not necessarily the same as
// the list editor for action/widget parameter configuration.
//
// Xcode 27.1 established that @Parameter(size:) is unavailable for [String];
// that initializer is constrained to app entities, file entities and certain
// system types. We therefore test requestValue() and needsValueError()
// separately on [String] and test size: using a small, valid AppEntity.

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

/// Probe 1. requestValue() on [String] is statically typed to return
/// a *single String*, not the full list, as verified by the Xcode compiler.
/// Observe which native prompt appears when running the Shortcut.
struct RuntimePlainTextListIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Text Array requestValue"
    static let description = IntentDescription(
        "Runtime experiment: ask for a value on an optional String array. Check whether the system asks for one string or shows a list editor."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Text items", description: "Leave empty to test the runtime prompt.")
    var items: [String]?

    static var parameterSummary: some ParameterSummary {
        Summary("Request a text item from \(\.$items)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Confirmed in the Xcode 27.1 SDK: return type is String, despite the
        // containing parameter's declared type being Optional<[String]>.
        let oneNewValue: String = try await $items.requestValue(
            "הקלד פריט טקסט אחד — האם מוצג עורך רשימה?"
        )
        var collected = items ?? []
        collected.append(oneNewValue)
        return .result(value: RuntimeTextListExperiment.resultText(
            collected,
            variant: "requestValue() on [String] returned one String"
        ))
    }
}

/// Probe 2. The needsValueError path asks the system to fill the *parameter*
/// and restart perform(). This may result in a different host UI than the
/// single-element requestValue() call. It is the highest-value experiment for
/// a complete list editor at runtime without a size: initializer.
struct RuntimeWholeTextListIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Text Array needsValue"
    static let description = IntentDescription(
        "Runtime experiment: force Shortcuts to resolve a whole String array using needsValueError and resume the action."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Entire text list", description: "Leave this empty in the Shortcut editor.")
    var items: [String]?

    static var parameterSummary: some ParameterSummary {
        Summary("Request the entire text list \(\.$items)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let items else {
            throw $items.needsValueError(
                "אנא הזן רשימה של פריטי טקסט"
            )
        }
        return .result(value: RuntimeTextListExperiment.resultText(
            items,
            variant: "needsValueError() resolved full [String]"
        ))
    }
}

// MARK: - Correctly constrained @Parameter(size:) control

struct RuntimeListChoiceEntity: AppEntity, Sendable, Hashable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lab List Item")
    static let defaultQuery = RuntimeListChoiceQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let options: [RuntimeListChoiceEntity] = [
        .init(id: "a", name: "פריט ראשון"),
        .init(id: "b", name: "פריט שני"),
        .init(id: "c", name: "פריט שלישי"),
        .init(id: "d", name: "מסמך לדוגמה")
    ]
}

struct RuntimeListChoiceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RuntimeListChoiceEntity] {
        identifiers.compactMap { id in
            RuntimeListChoiceEntity.options.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [RuntimeListChoiceEntity] {
        RuntimeListChoiceEntity.options
    }
}

/// Probe 3. A supported sized AppEntity array, unlike [String]. Leave the
/// parameter empty, run the Shortcut, and watch whether needsValueError()
/// produces the desired add/remove/reorder editor or a generic picker.
/// Also inspect how the parameter looks *while editing* the Shortcut.
struct RuntimeSizedEntityListIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Sized Entity List"
    static let description = IntentDescription(
        "Compare runtime list editing for a supported sized AppEntity array (1-8 items). No contacts or external data needed."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "List items",
        description: "Choose 1-8 test items; duplicates/order may be supported.",
        size: .init(min: 1, max: 8)
    )
    var items: [RuntimeListChoiceEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary("Request a sized entity list \(\.$items)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let items else {
            throw $items.needsValueError(
                "בחר פריטים והוסף אותם לרשימה"
            )
        }
        return .result(value: RuntimeTextListExperiment.resultText(
            items.map(\.name),
            variant: "SIZED AppEntity array, min 1 max 8"
        ))
    }
}
