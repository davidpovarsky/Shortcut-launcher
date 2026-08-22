import AppIntents
import CoreSpotlight
import Foundation

struct SpotlightNativeProbeRecord: Codable, Sendable {
    var id: String
    var title: String
    var searchableText: String
}

enum SpotlightNativeProbeService {
    static let titleKey = "lab.nativeProbe.title"
    static let textKey = "lab.nativeProbe.text"
    static let genericRecordKey = "lab.nativeProbe.generic.record"
    static let textContentRecordKey = "lab.nativeProbe.textContent.record"

    static let genericIndexName = "DavLauncherNativeSemanticProbe"
    static let textContentIndexName = "DavLauncherTextContentProbe"

    static var savedTitle: String {
        get { AppEnvironment.sharedDefaults.string(forKey: titleKey) ?? "Sefaria Native Probe" }
        set { AppEnvironment.sharedDefaults.set(newValue, forKey: titleKey) }
    }

    static var savedSearchableText: String {
        get {
            AppEnvironment.sharedDefaults.string(forKey: textKey)
                ?? "Jewish library of Torah, Talmud, Mishnah, Midrash, Halakha and commentaries"
        }
        set { AppEnvironment.sharedDefaults.set(newValue, forKey: textKey) }
    }

    static func indexProbes(title: String, searchableText: String) async throws {
        savedTitle = title
        savedSearchableText = searchableText

        let generic = SpotlightNativeProbeRecord(
            id: "native.semantic.generic",
            title: title + " [contentDescription IndexedEntity]",
            searchableText: searchableText
        )
        let textContent = SpotlightNativeProbeRecord(
            id: "native.semantic.textContent",
            title: title + " [textContent IndexedEntity]",
            searchableText: searchableText
        )
        save(generic, key: genericRecordKey)
        save(textContent, key: textContentRecordKey)

        let genericIndex = CSSearchableIndex(name: genericIndexName)
        try await genericIndex.deleteAppEntities(ofType: SpotlightNativeProbeEntity.self)
        try await genericIndex.indexAppEntities([SpotlightNativeProbeEntity(record: generic)], priority: 100)

        let textContentIndex = CSSearchableIndex(name: textContentIndexName)
        try await textContentIndex.deleteAppEntities(ofType: SpotlightTextContentProbeEntity.self)
        try await textContentIndex.indexAppEntities([SpotlightTextContentProbeEntity(record: textContent)], priority: 100)

        DiagnosticLog.record(
            "spotlight.nativeProbes.indexed",
            details: [
                "title": title,
                "searchableText": searchableText,
                "probes": "contentDescription,textContent"
            ]
        )
        DiagnosticLog.syncSharedLogToDocuments()
    }

    static func removeProbes() async throws {
        try await CSSearchableIndex(name: genericIndexName).deleteAppEntities(ofType: SpotlightNativeProbeEntity.self)
        try await CSSearchableIndex(name: textContentIndexName).deleteAppEntities(ofType: SpotlightTextContentProbeEntity.self)
        DiagnosticLog.record("spotlight.nativeProbes.removed")
        DiagnosticLog.syncSharedLogToDocuments()
    }

    fileprivate static func genericRecord(id: String) -> SpotlightNativeProbeRecord? {
        record(for: id, key: genericRecordKey)
    }

    fileprivate static func textContentRecord(id: String) -> SpotlightNativeProbeRecord? {
        record(for: id, key: textContentRecordKey)
    }

    private static func save(_ record: SpotlightNativeProbeRecord, key: String) {
        if let data = try? JSONEncoder().encode(record) {
            AppEnvironment.sharedDefaults.set(data, forKey: key)
        }
    }

    private static func record(for id: String, key: String) -> SpotlightNativeProbeRecord? {
        guard let data = AppEnvironment.sharedDefaults.data(forKey: key),
              let record = try? JSONDecoder().decode(SpotlightNativeProbeRecord.self, from: data),
              record.id == id else {
            return nil
        }
        return record
    }
}

struct SpotlightNativeProbeEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Native Spotlight contentDescription Probe"
    static let defaultQuery = NativeProbeQuery()

    let record: SpotlightNativeProbeRecord

    init(record: SpotlightNativeProbeRecord) {
        self.record = record
    }

    var id: String { record.id }

    @ComputedProperty(indexingKey: \.displayName)
    var indexedName: String { record.title }

    @ComputedProperty(indexingKey: \.contentDescription)
    var indexedSearchableText: String { record.searchableText }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(indexedName)", subtitle: "IndexedEntity • contentDescription")
    }

    struct NativeProbeQuery: EntityQuery {
        func entities(for identifiers: [String]) async throws -> [SpotlightNativeProbeEntity] {
            identifiers.compactMap { id in
                guard let record = SpotlightNativeProbeService.genericRecord(id: id) else { return nil }
                return SpotlightNativeProbeEntity(record: record)
            }
        }
    }
}

struct SpotlightTextContentProbeEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Native Spotlight textContent Probe"
    static let defaultQuery = TextContentProbeQuery()

    let record: SpotlightNativeProbeRecord

    init(record: SpotlightNativeProbeRecord) {
        self.record = record
    }

    var id: String { record.id }

    @ComputedProperty(indexingKey: \.displayName)
    var indexedName: String { record.title }

    @ComputedProperty(indexingKey: \.textContent)
    var indexedTextContent: String { record.searchableText }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(indexedName)", subtitle: "IndexedEntity • textContent")
    }

    struct TextContentProbeQuery: EntityQuery {
        func entities(for identifiers: [String]) async throws -> [SpotlightTextContentProbeEntity] {
            identifiers.compactMap { id in
                guard let record = SpotlightNativeProbeService.textContentRecord(id: id) else { return nil }
                return SpotlightTextContentProbeEntity(record: record)
            }
        }
    }
}
