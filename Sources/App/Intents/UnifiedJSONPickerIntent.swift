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

        // Only rich and menu AppEntities need App Group re-resolution.
        let representations = await MainActor.run {
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
        try MixedMenuChoiceStore.save(representations, session: session)
        defer { MixedMenuChoiceStore.remove(session: session) }

        let choices: [UnifiedNativePickerValue] = entries.enumerated().map { index, entry in
            let representation = representations[index]
            switch entry.format {
            case .richObject:
                return .rich(UnifiedRichObjectEntity(menuEntry: representation))
            case .contact:
                return .contact(contact(entry: entry, id: representation.id))
            case .menu:
                return .menu(representation)
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
            guard case let .applicationDefined(id) = person.identifier?.value else {
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
