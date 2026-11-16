import AppIntents
import Foundation

/// The same native values are used both for the runtime picker and for the
/// no-picker list action. No rich object is converted through a menu surrogate.
struct UnifiedNativeItemBatch {
    let session: String
    let entries: [UnifiedPickerEntry]
    let values: [UnifiedNativePickerValue]

    func index(of selected: UnifiedNativePickerValue) -> Int? {
        let identifier: String
        switch selected {
        case let .rich(entity):
            identifier = entity.id
        case let .menu(entity):
            identifier = entity.id
        case let .contact(person):
            guard case let .applicationDefined(id) = person.identifier else {
                return nil
            }
            identifier = id
        }
        let prefix = session + ":"
        guard identifier.hasPrefix(prefix),
              let index = Int(identifier.dropFirst(prefix.count)),
              entries.indices.contains(index) else {
            return nil
        }
        // Avoid accidentally accepting a matching session/index under a
        // different case if Shortcuts ever hands us a malformed selection.
        switch (entries[index].format, selected) {
        case (.richObject, .rich), (.contact, .contact), (.menu, .menu):
            return index
        default:
            return nil
        }
    }
}

enum UnifiedNativeItemBuilder {
    static func prepare(_ mixedJSON: String) async throws -> UnifiedNativeItemBatch {
        let entries = try UnifiedPickerParser.parse(mixedJSON)
        let session = UUID().uuidString

        let values: [UnifiedNativePickerValue] = await MainActor.run {
            entries.enumerated().map { index, entry in
                let identifier = "\(session):\(index)"
                switch entry.format {
                case .richObject:
                    // EXACTLY the entity returned by the original searchable
                    // rich object action, including its original thumbnail.
                    return .rich(UnifiedRichSampleFactory.make(
                        entry: entry, id: identifier
                    ))
                case .contact:
                    return .contact(makeContact(entry: entry, id: identifier))
                case .menu:
                    return .menu(MixedMenuChoiceEntity(
                        id: identifier,
                        title: entry.appearance.title,
                        subtitle: entry.appearance.subtitle,
                        type: entry.appearance.type,
                        imageData: MixedMenuIconRenderer.image(for: entry.appearance)
                    ))
                }
            }
        }

        // Shortcuts may re-query app entities after perform() returns. Keep
        // the session-scoped objects in the existing App Group stores for 1 h.
        let rich: [SearchableRichSampleEntity] = values.compactMap {
            if case let .rich(entity) = $0 { return entity }
            return nil
        }
        let menu: [MixedMenuChoiceEntity] = values.compactMap {
            if case let .menu(entity) = $0 { return entity }
            return nil
        }
        try SearchableRichRuntimeStore.save(rich, session: session)
        do {
            try MixedMenuChoiceStore.save(menu, session: session)
        } catch {
            SearchableRichRuntimeStore.remove(session: session)
            throw error
        }

        return UnifiedNativeItemBatch(session: session, entries: entries, values: values)
    }

    private static func makeContact(entry: UnifiedPickerEntry, id: String) -> IntentPerson {
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
        // This is a native IntentPerson value, NOT a write to Contacts.
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
