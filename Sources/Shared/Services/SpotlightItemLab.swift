import AppIntents
import Contacts
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

struct SpotlightCustomAttributeConfiguration: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var keyName = "com_dav_DavLauncher_lab_terms"
    var values: [String] = []
    var searchable = true
    var searchableByDefault = true
    var unique = false
    var multiValued = true
}

enum SpotlightLabSemanticMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case associateEntity
    case directEntity
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .associateEntity: "Associate IndexedEntity"
        case .directEntity: "Index entity separately"
        case .both: "Associate + separate entity"
        }
    }
}

enum SpotlightLabPreviewMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case generalSearch
    case berakhot
    case reference
    case diagnosticOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generalSearch: "Sefaria general search"
        case .berakhot: "Sefaria Berakhot search"
        case .reference: "Sefaria reference lookup"
        case .diagnosticOnly: "Diagnostics only"
        }
    }
}

struct SpotlightLabItemConfiguration: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var enabled = true
    var experimentLabel = "Custom Item"

    var uniqueIdentifier = "lab.custom.\(UUID().uuidString.lowercased())"
    var domainIdentifier = SefariaSpotlightLab.domainIdentifier
    var contentTypeIdentifier = UTType.item.identifier
    var contentTypeTree: [String] = []
    var expirationDays = 0
    var isUpdate = false

    var title = "Search Sefaria"
    var displayName = ""
    var alternateNames: [String] = []
    var keywords: [String] = []
    var contentDescription = ""
    var textContent = ""
    var subject = ""
    var theme = ""
    var creator = ""
    var audiences: [String] = []

    var containerIdentifier = ""
    var containerTitle = ""
    var containerDisplayName = ""
    var containerOrder = 0

    var authorNames: [String] = []
    var authorAddresses: [String] = []
    var authorEmailAddresses: [String] = []
    var recipientNames: [String] = []
    var recipientAddresses: [String] = []
    var recipientEmailAddresses: [String] = []
    var emailAddresses: [String] = []
    var mailboxIdentifiers: [String] = []
    var accountHandles: [String] = []
    var accountIdentifier = ""
    var phoneNumbers: [String] = []
    var instantMessageAddresses: [String] = []

    var rankingHint = 50
    var userCreated = false
    var userCurated = false
    var userOwned = false

    var customAttributes: [SpotlightCustomAttributeConfiguration] = []

    var semanticMode: SpotlightLabSemanticMode = .none
    var entityPriority = 10
    var entitySearchText = ""

    var previewMode: SpotlightLabPreviewMode = .generalSearch
    var queryPrefixesToStrip: [String] = ["Search Sefaria", "Sefaria", "חיפוש ספריא", "ספריא"]

    static func defaultItems() -> [SpotlightLabItemConfiguration] {
        var general = SpotlightLabItemConfiguration()
        general.experimentLabel = "General Sefaria Search"
        general.uniqueIdentifier = SefariaSpotlightLab.generalSearchIdentifier
        general.title = "Search Sefaria"
        general.contentDescription = "Preview this result to perform a live Sefaria API search."
        general.keywords = ["Sefaria", "ספריא", "חיפוש ספריא", "Jewish texts", "Torah", "Talmud"]
        general.previewMode = .generalSearch

        var berakhot = SpotlightLabItemConfiguration()
        berakhot.experimentLabel = "Berakhot Search"
        berakhot.uniqueIdentifier = SefariaSpotlightLab.berakhotSearchIdentifier
        berakhot.title = "Sefaria — Berakhot"
        berakhot.contentDescription = "Live Sefaria search scoped to Talmud Bavli, Berakhot."
        berakhot.keywords = ["Sefaria", "ספריא", "Berakhot", "ברכות", "Talmud", "תלמוד", "גמרא"]
        berakhot.previewMode = .berakhot

        var reference = SpotlightLabItemConfiguration()
        reference.experimentLabel = "Reference Lookup"
        reference.uniqueIdentifier = SefariaSpotlightLab.referenceSearchIdentifier
        reference.title = "Sefaria Reference Lookup"
        reference.contentDescription = "Use the Spotlight query for live Sefaria reference suggestions."
        reference.keywords = ["Sefaria", "ספריא", "reference", "מראה מקום", "מקור", "פסוק", "דף"]
        reference.previewMode = .reference

        return [general, berakhot, reference]
    }
}

enum SpotlightItemLabStore {
    static let storageKey = "lab.spotlightItems.configuration.v1"
    static let lastIndexedIdentifiersKey = "lab.spotlightItems.lastIndexedIdentifiers"

    static var items: [SpotlightLabItemConfiguration] {
        get {
            guard let data = AppEnvironment.sharedDefaults.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([SpotlightLabItemConfiguration].self, from: data),
                  !decoded.isEmpty else {
                let defaults = SpotlightLabItemConfiguration.defaultItems()
                save(defaults, reason: "bootstrap.defaults")
                return defaults
            }
            return decoded
        }
        set {
            save(newValue, reason: "store.setter")
        }
    }

    static func save(_ items: [SpotlightLabItemConfiguration], reason: String) {
        guard let data = try? JSONEncoder().encode(items) else {
            DiagnosticLog.record("spotlight.lab.store.encodeFailed", details: ["reason": reason])
            return
        }
        AppEnvironment.sharedDefaults.set(data, forKey: storageKey)
        DiagnosticLog.record(
            "spotlight.lab.store.saved",
            details: ["reason": reason, "count": String(items.count)]
        )
    }

    static func resetToDefaults() -> [SpotlightLabItemConfiguration] {
        let defaults = SpotlightLabItemConfiguration.defaultItems()
        save(defaults, reason: "reset.defaults")
        return defaults
    }

    static func configuration(for identifier: String) -> SpotlightLabItemConfiguration? {
        items.first { $0.uniqueIdentifier == identifier }
    }

    static func duplicate(_ item: SpotlightLabItemConfiguration) -> SpotlightLabItemConfiguration {
        var copy = item
        copy.id = UUID()
        copy.uniqueIdentifier = "lab.custom.\(UUID().uuidString.lowercased())"
        copy.experimentLabel += " Copy"
        copy.title += " Copy"
        return copy
    }

    static func generateAttributeMatrix(token rawToken: String) -> [SpotlightLabItemConfiguration] {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "elephant" : rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let stamp = UUID().uuidString.lowercased().prefix(8)

        func base(_ letter: String, _ label: String) -> SpotlightLabItemConfiguration {
            var item = SpotlightLabItemConfiguration()
            item.experimentLabel = "[\(letter)] \(label)"
            item.uniqueIdentifier = "lab.matrix.\(stamp).\(letter.lowercased())"
            item.title = "[\(letter)] Search Sefaria — \(label)"
            // Keep the actual token out of every shared field. It must exist only
            // in the field this variant is designed to test.
            item.contentDescription = "Attribute matrix control item. The test token is stored only in this variant's named field."
            item.previewMode = .diagnosticOnly
            item.rankingHint = 90
            return item
        }

        var a = base("A", "Title")
        a.title += " \(token)"

        var b = base("B", "Keywords")
        b.keywords = [token]

        var c = base("C", "Alternate Names")
        c.alternateNames = [token]

        var d = base("D", "Custom Default")
        d.customAttributes = [
            SpotlightCustomAttributeConfiguration(
                keyName: "com_dav_DavLauncher_matrix_default",
                values: [token],
                searchable: true,
                searchableByDefault: true,
                unique: false,
                multiValued: true
            )
        ]

        var e = base("E", "Text Content")
        e.textContent = token

        var f = base("F", "Subject")
        f.subject = token

        var g = base("G", "Associated Entity")
        g.semanticMode = .associateEntity
        g.entitySearchText = token
        g.entityPriority = 100

        var h = base("H", "Mail-style")
        h.contentTypeIdentifier = UTType.emailMessage.identifier
        h.subject = token
        h.textContent = "Sefaria \(token)"
        h.authorNames = ["Sefaria Lab"]
        h.authorEmailAddresses = ["lab@sefaria.example"]
        h.recipientNames = ["Spotlight Tester"]
        h.recipientEmailAddresses = ["tester@example.com"]
        h.emailAddresses = ["lab@sefaria.example", "tester@example.com"]
        h.mailboxIdentifiers = ["INBOX"]
        h.semanticMode = .associateEntity
        h.entitySearchText = "Sefaria \(token)"
        h.entityPriority = 100

        return [a, b, c, d, e, f, g, h]
    }

    static func makeSearchableItem(_ configuration: SpotlightLabItemConfiguration) -> CSSearchableItem {
        let contentType = UTType(configuration.contentTypeIdentifier) ?? .item
        let attributes = CSSearchableItemAttributeSet(contentType: contentType)

        attributes.title = nonEmpty(configuration.title)
        attributes.displayName = nonEmpty(configuration.displayName)
        attributes.alternateNames = nilIfEmpty(configuration.alternateNames)
        attributes.keywords = nilIfEmpty(configuration.keywords)
        attributes.contentDescription = nonEmpty(configuration.contentDescription)
        attributes.textContent = nonEmpty(configuration.textContent)
        attributes.subject = nonEmpty(configuration.subject)
        attributes.theme = nonEmpty(configuration.theme)
        attributes.creator = nonEmpty(configuration.creator)
        attributes.audiences = nilIfEmpty(configuration.audiences)
        attributes.contentTypeTree = nilIfEmpty(configuration.contentTypeTree)

        attributes.containerIdentifier = nonEmpty(configuration.containerIdentifier)
        attributes.containerTitle = nonEmpty(configuration.containerTitle)
        attributes.containerDisplayName = nonEmpty(configuration.containerDisplayName)
        if configuration.containerOrder != 0 {
            attributes.containerOrder = NSNumber(value: configuration.containerOrder)
        }

        attributes.authorNames = nilIfEmpty(configuration.authorNames)
        attributes.authorAddresses = nilIfEmpty(configuration.authorAddresses)
        attributes.authorEmailAddresses = nilIfEmpty(configuration.authorEmailAddresses)
        attributes.recipientNames = nilIfEmpty(configuration.recipientNames)
        attributes.recipientAddresses = nilIfEmpty(configuration.recipientAddresses)
        attributes.recipientEmailAddresses = nilIfEmpty(configuration.recipientEmailAddresses)
        attributes.emailAddresses = nilIfEmpty(configuration.emailAddresses)
        attributes.mailboxIdentifiers = nilIfEmpty(configuration.mailboxIdentifiers)
        attributes.accountHandles = nilIfEmpty(configuration.accountHandles)
        attributes.accountIdentifier = nonEmpty(configuration.accountIdentifier)
        attributes.phoneNumbers = nilIfEmpty(configuration.phoneNumbers)
        attributes.instantMessageAddresses = nilIfEmpty(configuration.instantMessageAddresses)

        if configuration.contentTypeIdentifier == UTType.emailMessage.identifier {
            // Use the richer public mail metadata that Apple's current Core Spotlight
            // guidance uses for mail processing. This deliberately supplements the
            // string-only fields exposed by the editor instead of replacing them.
            let authors = makePeople(
                names: configuration.authorNames,
                emails: configuration.authorEmailAddresses
            )
            let recipients = makePeople(
                names: configuration.recipientNames,
                emails: configuration.recipientEmailAddresses
            )
            attributes.authors = authors.isEmpty ? nil : authors
            attributes.primaryRecipients = recipients.isEmpty ? nil : recipients
            attributes.contentCreationDate = Date()
            attributes.likelyJunk = NSNumber(value: false)

            var headers: [String: [Any]] = [:]
            if !configuration.subject.isEmpty { headers["Subject"] = [configuration.subject] }
            if !configuration.authorEmailAddresses.isEmpty { headers["From"] = configuration.authorEmailAddresses }
            if !configuration.recipientEmailAddresses.isEmpty { headers["To"] = configuration.recipientEmailAddresses }
            attributes.emailHeaders = headers.isEmpty ? nil : headers

            if !configuration.textContent.isEmpty {
                let escaped = configuration.textContent
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                attributes.htmlContentData = "<html><body><p>\(escaped)</p></body></html>".data(using: .utf8)
            }
        }

        attributes.rankingHint = NSNumber(value: min(max(configuration.rankingHint, 0), 100))
        attributes.userCreated = NSNumber(value: configuration.userCreated)
        attributes.userCurated = NSNumber(value: configuration.userCurated)
        attributes.userOwned = NSNumber(value: configuration.userOwned)

        for custom in configuration.customAttributes {
            guard let key = CSCustomAttributeKey(
                keyName: sanitizedCustomKeyName(custom.keyName),
                searchable: custom.searchable,
                searchableByDefault: custom.searchableByDefault,
                unique: custom.unique,
                multiValued: custom.multiValued
            ) else {
                DiagnosticLog.record(
                    "spotlight.lab.customKey.invalid",
                    details: ["key": custom.keyName, "item": configuration.uniqueIdentifier]
                )
                continue
            }

            if custom.multiValued {
                let values = custom.values.filter { !$0.isEmpty }.map { $0 as NSString }
                if !values.isEmpty {
                    attributes.setValue(values as NSArray, forCustomKey: key)
                }
            } else if let first = custom.values.first, !first.isEmpty {
                attributes.setValue(first as NSString, forCustomKey: key)
            }
        }

        if configuration.semanticMode == .associateEntity || configuration.semanticMode == .both {
            attributes.associateAppEntity(SpotlightLabIndexedEntity(configuration: configuration), priority: configuration.entityPriority)
        }

        let item = CSSearchableItem(
            uniqueIdentifier: configuration.uniqueIdentifier,
            domainIdentifier: configuration.domainIdentifier.isEmpty ? SefariaSpotlightLab.domainIdentifier : configuration.domainIdentifier,
            attributeSet: attributes
        )
        item.isUpdate = configuration.isUpdate
        if configuration.expirationDays > 0 {
            item.expirationDate = Calendar.current.date(byAdding: .day, value: configuration.expirationDays, to: Date())
        }
        if configuration.contentTypeIdentifier == UTType.emailMessage.identifier {
            item.updateListenerOptions = [.priority, .summarization]
        }
        return item
    }

    static func indexDirectEntities(from configurations: [SpotlightLabItemConfiguration]) async {
        let direct = configurations.filter { $0.semanticMode == .directEntity || $0.semanticMode == .both }
        let index = CSSearchableIndex(name: "DavLauncherSpotlightLabEntities")
        do {
            try await index.deleteAppEntities(ofType: SpotlightLabIndexedEntity.self)
            for configuration in direct {
                try await index.indexAppEntities(
                    [SpotlightLabIndexedEntity(configuration: configuration)],
                    priority: configuration.entityPriority
                )
            }
            DiagnosticLog.record("spotlight.lab.entities.indexed", details: ["count": String(direct.count)])
        } catch {
            DiagnosticLog.record("spotlight.lab.entities.failed", details: ["error": String(describing: error)])
        }
    }

    static func deleteDirectEntities() async {
        do {
            try await CSSearchableIndex(name: "DavLauncherSpotlightLabEntities").deleteAppEntities(ofType: SpotlightLabIndexedEntity.self)
            DiagnosticLog.record("spotlight.lab.entities.deleted")
        } catch {
            DiagnosticLog.record("spotlight.lab.entities.deleteFailed", details: ["error": String(describing: error)])
        }
    }

    static func diagnosticSummary(for configuration: SpotlightLabItemConfiguration) -> String {
        var lines: [String] = []
        lines.append("label=\(configuration.experimentLabel)")
        lines.append("identifier=\(configuration.uniqueIdentifier)")
        lines.append("contentType=\(configuration.contentTypeIdentifier)")
        lines.append("title=\(configuration.title)")
        if !configuration.displayName.isEmpty { lines.append("displayName=\(configuration.displayName)") }
        if !configuration.keywords.isEmpty { lines.append("keywords=\(configuration.keywords.joined(separator: " | "))") }
        if !configuration.alternateNames.isEmpty { lines.append("alternateNames=\(configuration.alternateNames.joined(separator: " | "))") }
        if !configuration.subject.isEmpty { lines.append("subject=\(configuration.subject)") }
        if !configuration.textContent.isEmpty { lines.append("textContent=\(configuration.textContent)") }
        lines.append("rankingHint=\(configuration.rankingHint)")
        lines.append("semanticMode=\(configuration.semanticMode.rawValue), priority=\(configuration.entityPriority)")
        if configuration.contentTypeIdentifier == UTType.emailMessage.identifier {
            lines.append("mailEnhancements=CSPerson authors/To + headers + HTML + creationDate + updateListenerOptions")
        }
        for custom in configuration.customAttributes {
            lines.append("custom[\(custom.keyName)]=\(custom.values.joined(separator: " | ")); searchable=\(custom.searchable); default=\(custom.searchableByDefault)")
        }
        return lines.joined(separator: "\n")
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nilIfEmpty(_ values: [String]) -> [String]? {
        let filtered = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    private static func makePeople(names: [String], emails: [String]) -> [CSPerson] {
        let count = max(names.count, emails.count)
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            let name = index < names.count ? nonEmpty(names[index]) : nil
            let email = index < emails.count ? nonEmpty(emails[index]) : nil
            guard name != nil || email != nil else { return nil }
            return CSPerson(
                displayName: name,
                handles: email.map { [$0] } ?? [],
                handleIdentifier: CNContactEmailAddressesKey
            )
        }
    }

    private static func sanitizedCustomKeyName(_ value: String) -> String {
        let raw = value.isEmpty ? "com_dav_DavLauncher_lab_custom" : value
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        var result = String(scalars)
        if result.hasPrefix("kMD") { result = "dav_" + result }
        return result
    }
}

struct SpotlightLabIndexedEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Spotlight Lab Item"
    static let defaultQuery = Query()

    let id: String
    let name: String
    let subtitle: String
    let searchableText: String
    let keywords: [String]
    let subject: String

    init(configuration: SpotlightLabItemConfiguration) {
        id = configuration.uniqueIdentifier
        name = configuration.title.isEmpty ? configuration.experimentLabel : configuration.title
        subtitle = configuration.experimentLabel
        let explicit = configuration.entitySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchableText = explicit.isEmpty
            ? ([configuration.contentDescription, configuration.textContent] + configuration.keywords + configuration.alternateNames)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            : explicit
        keywords = configuration.keywords
        subject = configuration.subject
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(indexedName)", subtitle: "\(subtitle)")
    }

    // These explicit indexing-key properties exercise the modern IndexedEntity
    // pipeline instead of relying only on attributeSet metadata.
    @ComputedProperty(indexingKey: \.displayName)
    var indexedName: String { name }

    @ComputedProperty(indexingKey: \.contentDescription)
    var indexedSearchableText: String { searchableText }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.textContent = searchableText
        attributes.keywords = keywords.isEmpty ? nil : keywords
        attributes.subject = subject.isEmpty ? nil : subject
        return attributes
    }

    struct Query: EntityQuery {
        func entities(for identifiers: [String]) async throws -> [SpotlightLabIndexedEntity] {
            let wanted = Set(identifiers)
            return SpotlightItemLabStore.items
                .filter { wanted.contains($0.uniqueIdentifier) }
                .map(SpotlightLabIndexedEntity.init(configuration:))
        }
    }
}
