import Foundation

/// The picker shares one visual AppEntity type, while preserving the original
/// source format and complete JSON payload in its output.
enum UnifiedPickerFormat: String, Sendable {
    case richObject
    case contact
    case menu
}

struct UnifiedPickerEntry: Sendable {
    let format: UnifiedPickerFormat
    let appearance: MixedMenuItem
    let outputJSON: String
}

enum UnifiedPickerError: LocalizedError {
    case invalidJSON
    case invalidRoot
    case empty
    case tooLarge
    case tooManyItems
    case invalidItem(Int, String)
    case missingSelection

    var errorDescription: String? {
        switch self {
        case .invalidJSON: "Mixed JSON is not valid JSON."
        case .invalidRoot: "Use an array of items, {\"items\": [...]}, or grouped richObjects/contacts/menuItems arrays."
        case .empty: "Mixed JSON contains no selectable items."
        case .tooLarge: "Mixed JSON exceeds the 1 MB input limit."
        case .tooManyItems: "Mixed JSON contains more than 80 items."
        case let .invalidItem(index, reason): "Item \(index + 1): \(reason)"
        case .missingSelection: "The selected item was not found in the current menu."
        }
    }
}

enum UnifiedPickerParser {
    private struct InputRow {
        let declaredFormat: UnifiedPickerFormat?
        let fields: [String: Any]
    }

    private static let groupedKeys: [(String, UnifiedPickerFormat)] = [
        ("richObjects", .richObject),
        ("contacts", .contact),
        ("menuItems", .menu)
    ]

    static func parse(_ input: String) throws -> [UnifiedPickerEntry] {
        guard input.utf8.count <= MixedMenuParser.maxInputBytes else {
            throw UnifiedPickerError.tooLarge
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: Data(input.utf8))
        } catch {
            throw UnifiedPickerError.invalidJSON
        }

        let rows: [InputRow]
        if let list = root as? [Any] {
            rows = try unpack(list, declaredFormat: nil)
        } else if let dictionary = root as? [String: Any] {
            let hasGroups = groupedKeys.contains { dictionary[$0.0] != nil }
            if let mixed = dictionary["items"] {
                guard !hasGroups, let list = mixed as? [Any] else {
                    throw UnifiedPickerError.invalidRoot
                }
                rows = try unpack(list, declaredFormat: nil)
            } else if hasGroups {
                // Group ordering is documented and deterministic. To interleave
                // entries across formats, the caller should use "items".
                var grouped: [InputRow] = []
                for (key, format) in groupedKeys {
                    guard let raw = dictionary[key] else { continue }
                    if let list = raw as? [Any] {
                        grouped += try unpack(list, declaredFormat: format)
                    } else if format == .menu, let named = raw as? [String: Any] {
                        grouped += try unpackNamedMenu(named)
                    } else {
                        throw UnifiedPickerError.invalidRoot
                    }
                }
                rows = grouped
            } else if dictionary["title"] != nil || dictionary["name"] != nil ||
                        dictionary["displayName"] != nil {
                rows = [InputRow(declaredFormat: nil, fields: dictionary)]
            } else {
                // Retain the legacy Menu JSON object-of-named-items shape.
                rows = try unpackNamedMenu(dictionary)
            }
        } else {
            throw UnifiedPickerError.invalidRoot
        }

        guard !rows.isEmpty else { throw UnifiedPickerError.empty }
        guard rows.count <= MixedMenuParser.maxItems else {
            throw UnifiedPickerError.tooManyItems
        }
        return try rows.enumerated().map { index, row in
            try convert(row, index: index)
        }
    }

    private static func unpack(
        _ list: [Any],
        declaredFormat: UnifiedPickerFormat?
    ) throws -> [InputRow] {
        try list.enumerated().map { index, value in
            guard let fields = value as? [String: Any] else {
                throw UnifiedPickerError.invalidItem(index, "Expected a JSON object.")
            }
            return InputRow(declaredFormat: declaredFormat, fields: fields)
        }
    }

    private static func unpackNamedMenu(_ dictionary: [String: Any]) throws -> [InputRow] {
        try dictionary.keys.sorted().enumerated().map { index, key in
            guard var fields = dictionary[key] as? [String: Any] else {
                throw UnifiedPickerError.invalidItem(index, "Named menu entry must be an object.")
            }
            if fields["id"] == nil { fields["id"] = key }
            return InputRow(declaredFormat: .menu, fields: fields)
        }
    }

    private static func convert(_ input: InputRow, index: Int) throws -> UnifiedPickerEntry {
        let fields = input.fields
        let format = try input.declaredFormat ?? inferFormat(fields, index: index)
        let title = firstString(fields, keys: ["title", "name", "displayName", "label"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw UnifiedPickerError.invalidItem(index, "A title or name is required.")
        }

        let id = firstString(fields, keys: ["id"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedID = id.isEmpty ? String(index + 1) : id
        let explicitSubtitle = firstString(fields, keys: ["subtitle"])
        let subtitle: String
        if !explicitSubtitle.isEmpty {
            subtitle = explicitSubtitle
        } else {
            switch format {
            case .richObject:
                subtitle = firstString(fields, keys: ["source", "category", "details"])
            case .contact:
                subtitle = firstString(fields, keys: ["email", "emailAddress", "phone", "handle"])
            case .menu:
                subtitle = firstString(fields, keys: ["description"])
            }
        }

        let defaultIcon: String
        let defaultColor: String
        switch format {
        case .richObject:
            defaultIcon = "doc.richtext"
            defaultColor = "#2563EB"
        case .contact:
            defaultIcon = "person.crop.circle.fill"
            defaultColor = "#0D9488"
        case .menu:
            defaultIcon = "square.grid.2x2.fill"
            defaultColor = "#64748B"
        }

        let icon = firstString(fields, keys: ["icon", "symbol"])
        let color = firstString(fields, keys: ["color"])
        let resolvedColor = color.isEmpty ? defaultColor : color
        let background = fields["backgroundColor"] as? String
        let imageBase64 = fields["imageBase64"] as? String
        guard MixedMenuParser.validHexColor(resolvedColor) else {
            throw UnifiedPickerError.invalidItem(index, "Invalid color; use #RRGGBB or #RRGGBBAA.")
        }
        if let background, !MixedMenuParser.validHexColor(background) {
            throw UnifiedPickerError.invalidItem(index, "Invalid backgroundColor.")
        }
        if let imageBase64 {
            guard let bytes = Data(base64Encoded: imageBase64),
                  bytes.count <= 250_000 else {
                throw UnifiedPickerError.invalidItem(index, "Invalid or oversized imageBase64 (250 KB max).")
            }
        }

        let menuType = (fields["type"] as? String ?? "rich").lowercased()
        if format == .menu, !["rich", "vcard", "menu"].contains(menuType) {
            throw UnifiedPickerError.invalidItem(index, "Menu type must be rich or vcard.")
        }
        let style = format == .menu && menuType == "vcard" ? "vcard" : "rich"

        // Preserve every user-provided field; never silently reinterpret a
        // Contacts-like JSON object as a real device Contact/IntentPerson.
        let envelope: [String: Any] = [
            "format": format.rawValue,
            "id": resolvedID,
            "item": fields
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys, .fragmentsAllowed]
        )
        guard let outputJSON = String(data: json, encoding: .utf8) else {
            throw UnifiedPickerError.invalidJSON
        }

        return UnifiedPickerEntry(
            format: format,
            appearance: MixedMenuItem(
                id: resolvedID,
                type: style,
                title: title,
                subtitle: subtitle,
                icon: icon.isEmpty ? defaultIcon : icon,
                color: resolvedColor,
                backgroundColor: background,
                imageBase64: imageBase64,
                rawJSON: outputJSON
            ),
            outputJSON: outputJSON
        )
    }

    private static func inferFormat(
        _ fields: [String: Any],
        index: Int
    ) throws -> UnifiedPickerFormat {
        if let value = fields["format"] as? String ?? fields["kind"] as? String ??
            fields["sourceType"] as? String {
            switch value.lowercased() {
            case "richobject", "rich-object", "object": return .richObject
            case "contact", "person", "intentperson": return .contact
            case "menu", "menuitem", "menu-item": return .menu
            default:
                throw UnifiedPickerError.invalidItem(index, "Unknown format: \(value).")
            }
        }

        if let type = fields["type"] as? String {
            switch type.lowercased() {
            case "contact", "person", "intentperson": return .contact
            case "richobject", "rich-object", "object": return .richObject
            case "menu", "rich", "vcard": return .menu
            default:
                throw UnifiedPickerError.invalidItem(index, "Unknown type: \(type).")
            }
        }
        if fields["email"] != nil || fields["emailAddress"] != nil ||
            fields["phone"] != nil || fields["handle"] != nil {
            return .contact
        }
        if fields["title"] != nil { return .menu }
        if fields["name"] != nil || fields["displayName"] != nil { return .richObject }
        throw UnifiedPickerError.invalidItem(index, "Set format to richObject, contact or menu.")
    }

    private static func firstString(_ object: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }
}
