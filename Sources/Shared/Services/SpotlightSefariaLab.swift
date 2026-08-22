import CoreSpotlight
import Foundation

struct SefariaPreviewItem: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let excerpt: String
}

struct SefariaPreviewPayload: Sendable {
    let identifier: String
    let rawQuery: String
    let effectiveQuery: String
    let modeTitle: String
    let resultCount: Int
    let items: [SefariaPreviewItem]
}

enum SefariaSpotlightLab {
    static let enabledKey = "lab.spotlightSefaria.enabled"
    static let domainIdentifier = "com.dav.DavLauncher.lab.sefaria"

    static let generalSearchIdentifier = "lab.sefaria.search.general"
    static let berakhotSearchIdentifier = "lab.sefaria.search.berakhot"
    static let referenceSearchIdentifier = "lab.sefaria.search.reference"

    static let lastPreviewIdentifierKey = "lab.spotlightSefaria.lastPreview.identifier"
    static let lastPreviewQueryKey = "lab.spotlightSefaria.lastPreview.query"
    static let lastPreviewStatusKey = "lab.spotlightSefaria.lastPreview.status"
    static let lastPreviewResultCountKey = "lab.spotlightSefaria.lastPreview.resultCount"
    static let lastPreviewErrorKey = "lab.spotlightSefaria.lastPreview.error"
    static let lastIndexStatusKey = "lab.spotlightSefaria.lastIndex.status"

    static var searchableIdentifiers: [String] {
        SpotlightItemLabStore.items.map(\.uniqueIdentifier)
    }

    static var isEnabled: Bool {
        get {
            let defaults = AppEnvironment.sharedDefaults
            if defaults.object(forKey: enabledKey) == nil {
                defaults.set(true, forKey: enabledKey)
                return true
            }
            return defaults.bool(forKey: enabledKey)
        }
        set {
            AppEnvironment.sharedDefaults.set(newValue, forKey: enabledKey)
        }
    }

    static func ensureIndexedIfEnabled(reason: String) {
        guard isEnabled else {
            DiagnosticLog.record("spotlight.sefaria.index.skipped", details: ["reason": reason, "enabled": "false"])
            return
        }
        indexItems(reason: reason)
    }

    static func indexItems(reason: String) {
        let configurations = SpotlightItemLabStore.items.filter(\.enabled)
        let items = configurations.map(SpotlightItemLabStore.makeSearchableItem)
        let itemCount = items.count
        let identifiers = configurations.map(\.uniqueIdentifier)
        let previousIdentifiers = AppEnvironment.sharedDefaults.stringArray(forKey: SpotlightItemLabStore.lastIndexedIdentifiersKey) ?? []
        let staleIdentifiers = previousIdentifiers.filter { !identifiers.contains($0) }

        DiagnosticLog.record(
            "spotlight.sefaria.index.requested",
            details: [
                "reason": reason,
                "count": String(itemCount),
                "staleCount": String(staleIdentifiers.count)
            ]
        )

        if !staleIdentifiers.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: staleIdentifiers) { error in
                if let error {
                    DiagnosticLog.record(
                        "spotlight.lab.staleDelete.failed",
                        details: ["error": String(describing: error), "count": String(staleIdentifiers.count)]
                    )
                } else {
                    DiagnosticLog.record(
                        "spotlight.lab.staleDelete.completed",
                        details: ["count": String(staleIdentifiers.count)]
                    )
                }
            }
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                AppEnvironment.sharedDefaults.set("error", forKey: lastIndexStatusKey)
                DiagnosticLog.record(
                    "spotlight.sefaria.index.failed",
                    details: ["reason": reason, "error": String(describing: error)]
                )
            } else {
                AppEnvironment.sharedDefaults.set("indexed \(itemCount) items", forKey: lastIndexStatusKey)
                AppEnvironment.sharedDefaults.set(identifiers, forKey: SpotlightItemLabStore.lastIndexedIdentifiersKey)
                DiagnosticLog.record(
                    "spotlight.sefaria.index.completed",
                    details: ["reason": reason, "count": String(itemCount)]
                )
                for configuration in configurations {
                    DiagnosticLog.record(
                        "spotlight.lab.item.indexed",
                        details: [
                            "label": configuration.experimentLabel,
                            "identifier": configuration.uniqueIdentifier,
                            "title": configuration.title,
                            "displayName": configuration.displayName,
                            "contentType": configuration.contentTypeIdentifier,
                            "keywords": configuration.keywords.joined(separator: " | "),
                            "alternateNames": configuration.alternateNames.joined(separator: " | "),
                            "subject": configuration.subject,
                            "textContent": configuration.textContent,
                            "customCount": String(configuration.customAttributes.count),
                            "semanticMode": configuration.semanticMode.rawValue,
                            "entityPriority": String(configuration.entityPriority),
                            "rankingHint": String(configuration.rankingHint)
                        ]
                    )
                }
            }
        }

        Task {
            await SpotlightItemLabStore.indexDirectEntities(from: configurations)
        }
    }

    static func removeItems(reason: String) {
        let previous = AppEnvironment.sharedDefaults.stringArray(forKey: SpotlightItemLabStore.lastIndexedIdentifiersKey) ?? []
        let identifiers = Array(Set(previous + searchableIdentifiers))
        DiagnosticLog.record(
            "spotlight.sefaria.remove.requested",
            details: ["reason": reason, "count": String(identifiers.count)]
        )
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { error in
            if let error {
                AppEnvironment.sharedDefaults.set("remove error", forKey: lastIndexStatusKey)
                DiagnosticLog.record(
                    "spotlight.sefaria.remove.failed",
                    details: ["reason": reason, "error": String(describing: error)]
                )
            } else {
                AppEnvironment.sharedDefaults.set("removed", forKey: lastIndexStatusKey)
                AppEnvironment.sharedDefaults.removeObject(forKey: SpotlightItemLabStore.lastIndexedIdentifiersKey)
                DiagnosticLog.record("spotlight.sefaria.remove.completed", details: ["reason": reason])
            }
        }
        Task {
            await SpotlightItemLabStore.deleteDirectEntities()
        }
    }

    static func recordPreviewStart(identifier: String, query: String?) {
        let defaults = AppEnvironment.sharedDefaults
        defaults.set(identifier, forKey: lastPreviewIdentifierKey)
        defaults.set(query ?? "", forKey: lastPreviewQueryKey)
        defaults.set("loading", forKey: lastPreviewStatusKey)
        defaults.set(0, forKey: lastPreviewResultCountKey)
        defaults.removeObject(forKey: lastPreviewErrorKey)
        DiagnosticLog.record(
            "spotlight.sefaria.preview.started",
            details: [
                "identifier": identifier,
                "query": query ?? "nil",
                "configuration": SpotlightItemLabStore.configuration(for: identifier)?.experimentLabel ?? "not found"
            ]
        )
    }

    static func recordPreviewSuccess(_ payload: SefariaPreviewPayload) {
        let defaults = AppEnvironment.sharedDefaults
        defaults.set("loaded", forKey: lastPreviewStatusKey)
        defaults.set(payload.resultCount, forKey: lastPreviewResultCountKey)
        defaults.removeObject(forKey: lastPreviewErrorKey)
        DiagnosticLog.record(
            "spotlight.sefaria.preview.loaded",
            details: [
                "identifier": payload.identifier,
                "rawQuery": payload.rawQuery,
                "effectiveQuery": payload.effectiveQuery,
                "mode": payload.modeTitle,
                "resultCount": String(payload.resultCount),
                "shownCount": String(payload.items.count)
            ]
        )
    }

    static func recordPreviewFailure(identifier: String, query: String?, error: Error) {
        let defaults = AppEnvironment.sharedDefaults
        defaults.set("error", forKey: lastPreviewStatusKey)
        defaults.set(String(describing: error), forKey: lastPreviewErrorKey)
        DiagnosticLog.record(
            "spotlight.sefaria.preview.failed",
            details: [
                "identifier": identifier,
                "query": query ?? "nil",
                "error": String(describing: error)
            ]
        )
    }

    static func diagnosticsSnapshot() -> [String: String] {
        let defaults = AppEnvironment.sharedDefaults
        return [
            "enabled": String(isEnabled),
            "indexStatus": defaults.string(forKey: lastIndexStatusKey) ?? "never indexed",
            "lastIdentifier": defaults.string(forKey: lastPreviewIdentifierKey) ?? "none",
            "lastQuery": defaults.string(forKey: lastPreviewQueryKey) ?? "none",
            "lastStatus": defaults.string(forKey: lastPreviewStatusKey) ?? "never previewed",
            "lastResultCount": String(defaults.integer(forKey: lastPreviewResultCountKey)),
            "lastError": defaults.string(forKey: lastPreviewErrorKey) ?? "none",
            "configuredItems": String(SpotlightItemLabStore.items.count)
        ]
    }
}

enum SefariaSpotlightAPI {
    enum APIError: LocalizedError {
        case emptyQuery
        case invalidResponse
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .emptyQuery: "Spotlight supplied only the configured prefix. Add search terms, or use Diagnostics-only preview mode."
            case .invalidResponse: "Sefaria returned an unexpected response."
            case .httpStatus(let status): "Sefaria returned HTTP \(status)."
            }
        }
    }

    static func loadPreview(identifier: String, rawQuery: String?) async throws -> SefariaPreviewPayload {
        let configuration = SpotlightItemLabStore.configuration(for: identifier)
        let mode = configuration?.previewMode ?? legacyPreviewMode(for: identifier)
        let raw = rawQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if mode == .diagnosticOnly {
            let summary = configuration.map(SpotlightItemLabStore.diagnosticSummary) ?? "No saved configuration was found for this identifier."
            return SefariaPreviewPayload(
                identifier: identifier,
                rawQuery: raw,
                effectiveQuery: raw,
                modeTitle: "Spotlight Item Lab diagnostics",
                resultCount: 1,
                items: [
                    SefariaPreviewItem(
                        id: "diagnostic-\(identifier)",
                        title: configuration?.experimentLabel ?? "Unknown Spotlight item",
                        subtitle: identifier,
                        excerpt: summary
                    )
                ]
            )
        }

        let effective = cleanedQuery(raw, identifier: identifier, configuration: configuration, mode: mode)
        guard !effective.isEmpty else { throw APIError.emptyQuery }

        if mode == .reference {
            return try await referenceLookup(identifier: identifier, rawQuery: raw, query: effective)
        }

        return try await textSearch(
            identifier: identifier,
            rawQuery: raw,
            query: effective,
            berakhotOnly: mode == .berakhot
        )
    }

    private static func textSearch(
        identifier: String,
        rawQuery: String,
        query: String,
        berakhotOnly: Bool
    ) async throws -> SefariaPreviewPayload {
        guard let url = URL(string: "https://www.sefaria.org/api/search-wrapper") else {
            throw APIError.invalidResponse
        }

        var body: [String: Any] = [
            "query": query,
            "type": "text",
            "size": 8,
            "start": 0,
            "source_proj": ["ref", "heRef", "path", "lang"]
        ]

        if containsHebrew(query) {
            body["field"] = "naive_lemmatizer"
            body["slop"] = 10
        } else {
            body["field"] = "exact"
        }

        if berakhotOnly {
            body["filters"] = ["Talmud/Bavli/Seder Zeraim/Berakhot"]
            body["filter_fields"] = ["path"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        DiagnosticLog.record(
            "spotlight.sefaria.api.request",
            details: [
                "kind": berakhotOnly ? "berakhot-text-search" : "text-search",
                "query": query
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.httpStatus(http.statusCode) }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any],
              let hitsContainer = root["hits"] as? [String: Any],
              let hitArray = hitsContainer["hits"] as? [[String: Any]] else {
            throw APIError.invalidResponse
        }

        let items = hitArray.enumerated().map { offset, hit in
            let source = hit["_source"] as? [String: Any] ?? [:]
            let ref = stringValue(source["ref"])
                ?? stringValue(source["heRef"])
                ?? stringValue(hit["_id"])
                ?? "Result \(offset + 1)"
            let heRef = stringValue(source["heRef"])
            let path = stringValue(source["path"]) ?? "Sefaria text"
            let excerpt = highlightText(from: hit) ?? "Live match from the Sefaria search index."
            return SefariaPreviewItem(
                id: stringValue(hit["_id"]) ?? "\(offset)-\(ref)",
                title: heRef ?? ref,
                subtitle: heRef == nil ? path : "\(ref) · \(path)",
                excerpt: cleanHTML(excerpt)
            )
        }

        let total = totalHitCount(hitsContainer["total"]) ?? items.count
        return SefariaPreviewPayload(
            identifier: identifier,
            rawQuery: rawQuery,
            effectiveQuery: query,
            modeTitle: berakhotOnly ? "Berakhot live search" : "Sefaria live text search",
            resultCount: total,
            items: items
        )
    }

    private static func referenceLookup(
        identifier: String,
        rawQuery: String,
        query: String
    ) async throws -> SefariaPreviewPayload {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        guard var components = URLComponents(string: "https://www.sefaria.org/api/name/\(encoded)") else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "8"),
            URLQueryItem(name: "type", value: "ref")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }

        DiagnosticLog.record(
            "spotlight.sefaria.api.request",
            details: ["kind": "reference-lookup", "query": query]
        )

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.httpStatus(http.statusCode) }

        let json = try JSONSerialization.jsonObject(with: data)
        let items = parseReferenceItems(json)
        return SefariaPreviewPayload(
            identifier: identifier,
            rawQuery: rawQuery,
            effectiveQuery: query,
            modeTitle: "Sefaria reference lookup",
            resultCount: items.count,
            items: items
        )
    }

    private static func parseReferenceItems(_ json: Any) -> [SefariaPreviewItem] {
        let dictionaries: [[String: Any]]
        if let root = json as? [String: Any] {
            dictionaries = (root["completion_objects"] as? [[String: Any]])
                ?? (root["results"] as? [[String: Any]])
                ?? []
            if dictionaries.isEmpty, let completions = root["completions"] as? [String] {
                return completions.prefix(8).enumerated().map { index, value in
                    SefariaPreviewItem(id: "completion-\(index)", title: value, subtitle: "Reference suggestion", excerpt: "Live suggestion from Sefaria Name API.")
                }
            }
        } else if let array = json as? [[String: Any]] {
            dictionaries = array
        } else if let strings = json as? [String] {
            return strings.prefix(8).enumerated().map { index, value in
                SefariaPreviewItem(id: "completion-\(index)", title: value, subtitle: "Reference suggestion", excerpt: "Live suggestion from Sefaria Name API.")
            }
        } else {
            return []
        }

        return dictionaries.prefix(8).enumerated().map { index, item in
            let title = stringValue(item["title"])
                ?? stringValue(item["ref"])
                ?? stringValue(item["key"])
                ?? stringValue(item["name"])
                ?? "Reference \(index + 1)"
            let subtitle = stringValue(item["type"]) ?? "Reference suggestion"
            let excerpt = stringValue(item["heTitle"])
                ?? stringValue(item["heRef"])
                ?? "Live suggestion from Sefaria Name API."
            return SefariaPreviewItem(id: "reference-\(index)-\(title)", title: title, subtitle: subtitle, excerpt: excerpt)
        }
    }

    private static func cleanedQuery(
        _ raw: String,
        identifier: String,
        configuration: SpotlightLabItemConfiguration?,
        mode: SpotlightLabPreviewMode
    ) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = configuration?.queryPrefixesToStrip ?? ["Search Sefaria", "Sefaria", "חיפוש ספריא", "ספריא"]
        for prefix in prefixes where !prefix.isEmpty {
            if result.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                break
            }
        }

        if mode == .berakhot {
            for token in ["Berakhot", "ברכות"] {
                result = result.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
            }
        } else if mode == .reference {
            for token in ["Reference", "lookup", "מראה מקום", "מקור"] {
                result = result.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func legacyPreviewMode(for identifier: String) -> SpotlightLabPreviewMode {
        if identifier == SefariaSpotlightLab.berakhotSearchIdentifier { return .berakhot }
        if identifier == SefariaSpotlightLab.referenceSearchIdentifier { return .reference }
        return .generalSearch
    }

    private static func containsHebrew(_ string: String) -> Bool {
        string.unicodeScalars.contains { scalar in
            (0x0590...0x05FF).contains(Int(scalar.value))
        }
    }

    private static func totalHitCount(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let dictionary = value as? [String: Any] {
            if let int = dictionary["value"] as? Int { return int }
            if let number = dictionary["value"] as? NSNumber { return number.intValue }
        }
        return nil
    }

    private static func highlightText(from hit: [String: Any]) -> String? {
        guard let highlight = hit["highlight"] as? [String: Any] else { return nil }
        for key in highlight.keys.sorted() {
            if let fragments = highlight[key] as? [String], let first = fragments.first {
                return first
            }
            if let fragment = highlight[key] as? String {
                return fragment
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        if let values = value as? [String], let first = values.first { return first }
        return nil
    }

    private static func cleanHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
