import AppIntents
import Foundation

// MARK: - iOS 27 system picker experiments

struct SystemPickerSampleEntity: AppEntity, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "System Picker Item")
    static let defaultQuery = SystemPickerSampleEntityQuery()

    let id: String
    let title: String
    let subtitle: String
    let symbolName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)",
            image: DisplayRepresentation.Image(systemName: symbolName, isTemplate: true)
        )
    }

    static let samples: [SystemPickerSampleEntity] = [
        .init(id: "ai-quick-info", title: "AI Quick Info", subtitle: "Recent tool", symbolName: "sparkles"),
        .init(id: "translate", title: "Translate", subtitle: "Recent tool", symbolName: "character.bubble"),
        .init(id: "wikipedia", title: "Wikipedia", subtitle: "Recent tool", symbolName: "book.closed"),
        .init(id: "telegram", title: "Telegram Search", subtitle: "Favorite", symbolName: "paperplane"),
        .init(id: "sefaria", title: "Sefaria", subtitle: "Favorite", symbolName: "books.vertical"),
        .init(id: "transit", title: "Transit", subtitle: "Favorite", symbolName: "bus")
    ]
}

struct SystemPickerSampleEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SystemPickerSampleEntity] {
        let requested = Set(identifiers)
        return SystemPickerSampleEntity.samples.filter { requested.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SystemPickerSampleEntity] {
        SystemPickerSampleEntity.samples
    }
}

struct SystemPickerOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<SystemPickerSampleEntity> {
        let recent = IntentItemSection<SystemPickerSampleEntity>(
            "Recent",
            items: [
                IntentItem<SystemPickerSampleEntity>(
                    SystemPickerSampleEntity.samples[0],
                    title: "AI Quick Info",
                    subtitle: "Recent tool",
                    image: DisplayRepresentation.Image(systemName: "sparkles", isTemplate: true)
                ),
                IntentItem<SystemPickerSampleEntity>(
                    SystemPickerSampleEntity.samples[1],
                    title: "Translate",
                    subtitle: "Recent tool",
                    image: DisplayRepresentation.Image(systemName: "character.bubble", isTemplate: true)
                ),
                IntentItem<SystemPickerSampleEntity>(
                    SystemPickerSampleEntity.samples[2],
                    title: "Wikipedia",
                    subtitle: "Recent tool",
                    image: DisplayRepresentation.Image(systemName: "book.closed", isTemplate: true)
                )
            ]
        )

        let favorites = IntentItemSection<SystemPickerSampleEntity>(
            "Favorites",
            items: [
                IntentItem<SystemPickerSampleEntity>(
                    SystemPickerSampleEntity.samples[3],
                    title: "Telegram Search",
                    subtitle: "Favorite",
                    image: DisplayRepresentation.Image(systemName: "paperplane", isTemplate: true)
                ),
                IntentItem<SystemPickerSampleEntity>(
                    SystemPickerSampleEntity.samples[4],
                    title: "Sefaria",
                    subtitle: "Favorite",
                    image: DisplayRepresentation.Image(systemName: "books.vertical", isTemplate: true)
                ),
                IntentItem<SystemPickerSampleEntity>(
                    SystemPickerSampleEntity.samples[5],
                    title: "Transit",
                    subtitle: "Favorite",
                    image: DisplayRepresentation.Image(systemName: "bus", isTemplate: true)
                )
            ]
        )

        return IntentItemCollection<SystemPickerSampleEntity>(
            promptLabel: "Choose an item",
            sections: [recent, favorites]
        )
    }
}

struct ExperimentalDurationPickerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Native Duration Picker"
    static let description = IntentDescription(
        "Tests the iOS 27 system-hosted Duration parameter picker."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Duration",
        requestValueDialog: "Choose a duration"
    )
    var duration: Duration

    static var parameterSummary: some ParameterSummary {
        Summary("Test native duration picker with \(\.$duration)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Duration selected.")
    }
}

struct ExperimentalRichEntityPickerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Rich Entity Picker"
    static let description = IntentDescription(
        "Tests a system-hosted AppEntity picker with sections, subtitles, and images."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Item",
        requestValueDialog: "Choose an item",
        requestDisambiguationDialog: "Which item do you want?",
        optionsProvider: SystemPickerOptionsProvider()
    )
    var item: SystemPickerSampleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Test rich system picker with \(\.$item)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Selected \(item.title).")
    }
}

struct ExperimentalRuntimeRequestValueIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Runtime Value Prompt"
    static let description = IntentDescription(
        "Leaves an optional value empty so perform() can request it from the system at runtime."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Label",
        requestValueDialog: "Enter a label"
    )
    var label: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Test runtime value prompt")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedLabel: String
        if let label, !label.isEmpty {
            resolvedLabel = label
        } else {
            resolvedLabel = try await $label.requestValue(
                "Type a label in the system prompt"
            )
        }

        return .result(dialog: "Received \(resolvedLabel).")
    }
}

struct ExperimentalRuntimeDisambiguationIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Runtime Disambiguation"
    static let description = IntentDescription(
        "Forces a system disambiguation list while the intent is running."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Choice")
    var choice: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Test runtime disambiguation")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedChoice: String
        if let choice, !choice.isEmpty {
            resolvedChoice = choice
        } else {
            resolvedChoice = try await $choice.requestDisambiguation(
                among: ["AI Quick Info", "Translate", "Wikipedia"],
                dialog: "Which tool should the system choose?"
            )
        }

        return .result(dialog: "Selected \(resolvedChoice).")
    }
}
