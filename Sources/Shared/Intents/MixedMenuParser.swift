import Foundation

/// A single row supplied by the caller. rawJSON preserves arbitrary payload fields.
struct MixedMenuItem: Equatable, Sendable {
    let id: String
    let type: String
    let title: String
    let subtitle: String
    let icon: String
    let color: String
    let backgroundColor: String?
    let imageBase64: String?
    let rawJSON: String
}

enum MixedMenuInputError: LocalizedError {
    case invalidJSON
    case invalidRoot
    case empty
    case tooLarge
    case tooManyItems
    case invalidItem(Int, String)
    case duplicateID(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The menu input is not valid JSON."
        case .invalidRoot:
            return "The menu must be an array of objects or an object of named items."
        case .empty:
            return "The menu has no items."
        case .tooLarge:
            return "The menu JSON exceeds the 1 MB limit."
        case .tooManyItems:
            return "The menu contains more than 80 items."
        case let .invalidItem(index, reason):
            return "Menu item \(index + 1): \(reason)"
        case let .duplicateID(id):
            return "Menu item IDs must be unique. Duplicate: \(id)"
        }
    }
}

enum MixedMenuParser {
    static let maxItems = 80
    static let maxInputBytes = 1_000_000

    static func parse(_ input: String) throws -> [MixedMenuItem] {
        guard input.utf8.count <= maxInputBytes else {
            throw MixedMenuInputError.tooLarge
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: Data(input.utf8))
        } catch {
            throw MixedMenuInputError.invalidJSON
        }

        let entries: [(String?, [String: Any])]
        if let array = parsed as? [Any] {
            entries = try array.enumerated().map { index, element in
                guard let dictionary = element as? [String: Any] else {
                    throw MixedMenuInputError.invalidItem(index, "Expected an object.")
                }
                return (nil, dictionary)
            }
        } else if let dictionary = parsed as? [String: Any] {
            // Retain source key order for the existing Shortcuts workflow.
            let ordered = topLevelKeys(in: input)
            let keys = ordered.isEmpty ? dictionary.keys.sorted() : ordered
            entries = try keys.enumerated().map { index, key in
                guard let value = dictionary[key] as? [String: Any] else {
                    throw MixedMenuInputError.invalidItem(index, "Expected an object at key \(key).")
                }
                return (key, value)
            }
        } else {
            throw MixedMenuInputError.invalidRoot
        }

        guard !entries.isEmpty else { throw MixedMenuInputError.empty }
        guard entries.count <= maxItems else { throw MixedMenuInputError.tooManyItems }

        var seen = Set<String>()
        return try entries.enumerated().map { index, entry in
            let (sourceID, fields) = entry
            let id = ((fields["id"] as? String) ?? sourceID ?? "\(index + 1)")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = ((fields["title"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let type = (fields["type"] as? String ?? "rich").lowercased()
            let subtitle = fields["subtitle"] as? String ?? ""
            let icon = fields["icon"] as? String ?? "square.grid.2x2.fill"
            let color = fields["color"] as? String ?? "#64748B"
            let backgroundColor = fields["backgroundColor"] as? String
            let imageBase64 = fields["imageBase64"] as? String

            guard !id.isEmpty else { throw MixedMenuInputError.invalidItem(index, "Missing id.") }
            guard !title.isEmpty else { throw MixedMenuInputError.invalidItem(index, "Missing title.") }
            guard type == "rich" || type == "vcard" else {
                throw MixedMenuInputError.invalidItem(index, "type must be rich or vcard.")
            }
            guard validHexColor(color) else {
                throw MixedMenuInputError.invalidItem(index, "color must be #RRGGBB or #RRGGBBAA.")
            }
            if let backgroundColor, !validHexColor(backgroundColor) {
                throw MixedMenuInputError.invalidItem(index, "Invalid backgroundColor.")
            }
            if let imageBase64 {
                guard let data = Data(base64Encoded: imageBase64), data.count <= 250_000 else {
                    throw MixedMenuInputError.invalidItem(index, "imageBase64 is invalid or exceeds 250 KB.")
                }
            }
            guard seen.insert(id).inserted else {
                throw MixedMenuInputError.duplicateID(id)
            }

            // Return every supplied field unchanged, plus resolved ID/type.
            var normalized = fields
            normalized["id"] = id
            normalized["type"] = type
            let bytes = try JSONSerialization.data(
                withJSONObject: normalized,
                options: [.sortedKeys, .fragmentsAllowed]
            )
            guard let rawJSON = String(data: bytes, encoding: .utf8) else {
                throw MixedMenuInputError.invalidJSON
            }
            return MixedMenuItem(
                id: id, type: type, title: title, subtitle: subtitle,
                icon: icon, color: color, backgroundColor: backgroundColor,
                imageBase64: imageBase64, rawJSON: rawJSON
            )
        }
    }

    static func validHexColor(_ value: String) -> Bool {
        guard value.hasPrefix("#") else { return false }
        let digits = value.dropFirst()
        guard digits.count == 6 || digits.count == 8 else { return false }
        return digits.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains($0)
        }
    }

    /// Extract top-level object keys without confusing quoted or nested keys.
    private static func topLevelKeys(in json: String) -> [String] {
        let bytes = Array(json.utf8)
        var curlyDepth = 0
        var squareDepth = 0
        var inString = false
        var escaped = false
        var stringStart = 0
        var result: [String] = []

        for index in bytes.indices {
            let byte = bytes[index]
            if inString {
                if escaped {
                    escaped = false
                } else if byte == 92 {
                    escaped = true
                } else if byte == 34 {
                    inString = false
                    if curlyDepth == 1 && squareDepth == 0 {
                        var next = index + 1
                        while next < bytes.count && [9, 10, 13, 32].contains(bytes[next]) {
                            next += 1
                        }
                        if next < bytes.count && bytes[next] == 58,
                           let key = try? JSONDecoder().decode(
                            String.self, from: Data(bytes[stringStart...index])
                           ) {
                            result.append(key)
                        }
                    }
                }
                continue
            }
            switch byte {
            case 34:
                inString = true
                stringStart = index
            case 123: curlyDepth += 1
            case 125: curlyDepth -= 1
            case 91: squareDepth += 1
            case 93: squareDepth -= 1
            default: break
            }
        }
        return result
    }
}
