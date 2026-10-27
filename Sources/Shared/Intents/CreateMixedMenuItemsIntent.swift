import AppIntents
import Foundation
import UniformTypeIdentifiers

/// Experimental heterogeneous Shortcuts output. Do not confuse a rich AppEntity
/// with the private MenuItem produced by the third-party Actions app.
@UnionValue
enum MixedMenuOutputItem {
    case rich(MixedMenuChoiceEntity)
    case vcard(IntentFile)
}

extension MixedMenuOutputItem {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Mixed Menu Entry"
    }

    static let caseDisplayRepresentations: [Cases: DisplayRepresentation] = [
        .rich: "Rich Menu Item",
        .vcard: "vCard File"
    ]
}

enum MixedMenuVCardBuilder {
    static func make(_ item: MixedMenuItem, photo: Data?) -> IntentFile {
        let name = escape(item.title)
        let description = escape(item.subtitle)
        var lines = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:;\(name);;;",
            "FN:\(name)",
            "ORG:\(description)",
            "NOTE:\(escape(item.rawJSON))",
            "X-DAV-MENU-ID:\(escape(item.id))",
            "X-DAV-MENU-TYPE:vcard",
            "X-DAV-MENU-COLOR:\(escape(item.color))"
        ]
        if let photo {
            lines.append("PHOTO;ENCODING=b;TYPE=PNG:\(photo.base64EncodedString())")
        }
        lines.append("END:VCARD")
        let payload = lines.joined(separator: "\r\n") + "\r\n"
        let safeName = item.id.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ?
                String($0) : "_"
        }.joined()
        return IntentFile(
            data: Data(payload.utf8),
            filename: "\(safeName.isEmpty ? "menu-item" : safeName).vcf",
            type: UTType(filenameExtension: "vcf")
        )
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }
}

/// Produces mixed underlying AppEntity and genuine vCard file payloads.
/// Use Apple's separate "Choose from List" action on the resulting list.
struct CreateMixedMenuItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Mixed Menu Items"
    static let description = IntentDescription(
        "Create a heterogeneous list of rich app entities and real vCard files from JSON for Shortcuts Choose from List."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Menu JSON")
    var menuJSON: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create menu items from \(.$menuJSON)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<[MixedMenuOutputItem]> {
        let items = try MixedMenuParser.parse(menuJSON)
        let session = UUID().uuidString
        let entries: [MixedMenuOutputItem] = await MainActor.run {
            items.enumerated().map { index, item in
                let image = MixedMenuIconRenderer.image(for: item)
                if item.type == "vcard" {
                    return .vcard(MixedMenuVCardBuilder.make(item, photo: image))
                }
                return .rich(
                    MixedMenuChoiceEntity(
                        id: "\(session):\(index)",
                        title: item.title,
                        subtitle: item.subtitle,
                        type: item.type,
                        imageData: image
                    )
                )
            }
        }
        // Rich entries may need to be resolved by ID after the App Intent returns.
        try MixedMenuChoiceStore.save(
            entries.compactMap {
                if case let .rich(entity) = $0 { return entity }
                return nil
            },
            session: session
        )
        return .result(value: entries)
    }
}
