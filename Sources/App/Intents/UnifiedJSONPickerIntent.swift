import AppIntents
import Foundation

/// Pick one entry from a mixed JSON array without converting all underlying
/// items to the same AppEntity type. The union holds a real IntentPerson for
/// contacts, a rich AppEntity for objects, and an independent menu AppEntity.
struct UnifiedJSONPickerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Unified JSON Picker"
    static let description = IntentDescription(
        "Select from native rich objects, people, and menu entries supplied in one JSON."
    )
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    @Parameter(
        title: "Mixed JSON",
        description: "Array with format per item, or object with richObjects, contacts and menuItems."
    )
    var mixedJSON: String

    @Parameter(title: "Selected Item")
    var selectedItem: UnifiedNativePickerValue?

    static var parameterSummary: some ParameterSummary {
        Summary("Choose from mixed JSON \(\.$mixedJSON)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let entries = try UnifiedPickerParser.parse(mixedJSON)
        let session = UUID().uuidString

        // Build each case from its ORIGINAL concrete App Intents type.
        // The rich case never passes through MixedMenuChoiceEntity.
        let richRows: [(index: Int, entity: SearchableRichSampleEntity)] =
            await MainActor.run {
                entries.enumerated().compactMap { index, entry in
                    guard entry.format == .richObject else { return nil }
                    let entity = UnifiedRichSampleFactory.make(
                        entry: entry, id: "\(session):\(index)"
                    )
                    return (index: index, entity: entity)
                }
            }
        let menuRows: [(index: Int, entity: MixedMenuChoiceEntity)] =
            await MainActor.run {
                entries.enumerated().compactMap { index, entry in
                    guard entry.format == .menu else { return nil }
                    return (
                        index: index,
                        entity: MixedMenuChoiceEntity(
                            id: "\(session):\(index)",
                            title: entry.appearance.title,
                            subtitle: entry.appearance.subtitle,
                            type: entry.appearance.type,
                            imageData: MixedMenuIconRenderer.image(for: entry.appearance)
                        )
                    )
                }
            }

        // Shortcuts may re-query the entities during and after presentation.
        try SearchableRichRuntimeStore.save(richRows.map { $0.entity }, session: session)
        try MixedMenuChoiceStore.save(menuRows.map { $0.entity }, session: session)

        let richByIndex = Dictionary(uniqueKeysWithValues: richRows.map {
            ($0.index, $0.entity)
        })
        let menuByIndex = Dictionary(uniqueKeysWithValues: menuRows.map {
            ($0.index, $0.entity)
        })
        let choices: [UnifiedNativePickerValue] = try entries.enumerated().map { index, entry in
            switch entry.format {
            case .richObject:
                guard let rich = richByIndex[index] else {
                    throw UnifiedPickerError.missingSelection
                }
                return .rich(rich)
            case .contact:
                return .contact(contact(entry: entry, id: "\(session):\(index)"))
            case .menu:
                guard let menu = menuByIndex[index] else {
                    throw UnifiedPickerError.missingSelection
                }
                return .menu(menu)
            }
        }

        // The system receives genuinely different underlying value types.
        // Shortcuts still decides how a *single* mixed-type prompt is styled.
        let chosen = try await $selectedItem.requestDisambiguation(
            among: choices,
            dialog: "Choose a rich object, contact, or menu item"
        )

        let key: String
        switch chosen {
        case let .rich(object): key = object.id
        case let .menu(item): key = item.id
        case let .contact(person):
            guard case let .applicationDefined(id) = person.identifier else {
                throw UnifiedPickerError.missingSelection
            }
            key = id
        }

        guard key.hasPrefix(session + ":"),
              let index = Int(key.dropFirst(session.count + 1)),
              entries.indices.contains(index) else {
            throw UnifiedPickerError.missingSelection
        }
        return .result(value: entries[index].outputJSON)
    }

    private func contact(entry: UnifiedPickerEntry, id: String) -> IntentPerson {
        let payload = (try? JSONSerialization.jsonObject(
            with: Data(entry.outputJSON.utf8)
        ) as? [String: Any])?["item"] as? [String: Any] ?? [:]

        let email = (payload["email"] as? String) ?? (payload["emailAddress"] as? String)
        let phone = payload["phone"] as? String
        let handle: IntentPerson.Handle?
        if let email, !email.isEmpty {
            handle = .init(emailAddress: email)
        } else if let phone, !phone.isEmpty {
            handle = .init(phoneNumber: phone)
        } else {
            handle = nil
        }
        return IntentPerson(
            identifier: .applicationDefined(id),
            name: .displayName(entry.appearance.title),
            handle: handle,
            image: DisplayRepresentation.Image(
                systemName: "person.crop.circle.fill",
                isTemplate: true
            )
        )
    }
}
