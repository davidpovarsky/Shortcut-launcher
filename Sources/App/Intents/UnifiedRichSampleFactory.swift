import Foundation
import UIKit

/// Construct dynamic JSON rows as the ORIGINAL rich sample AppEntity, not as
/// MixedMenuChoiceEntity (or a look-alike entity with a different type).
@MainActor
enum UnifiedRichSampleFactory {
    static func make(entry: UnifiedPickerEntry, id: String) -> SearchableRichSampleEntity {
        let json = (try? JSONSerialization.jsonObject(
            with: Data(entry.outputJSON.utf8)
        ) as? [String: Any])?["item"] as? [String: Any] ?? [:]

        let details = json["details"] as? String ?? ""
        let source = json["source"] as? String ?? ""
        let category = json["category"] as? String ?? ""
        let tags: String
        if let array = json["tags"] as? [String] {
            tags = array.joined(separator: " ")
        } else {
            tags = json["tags"] as? String ?? ""
        }

        let iconPNG: Data
        if let base64 = entry.appearance.imageBase64,
           let imageData = Data(base64Encoded: base64),
           UIImage(data: imageData) != nil {
            iconPNG = imageData
        } else {
            // Match the original rich picker thumbnails: 88 px rounded tiles,
            // rather than the menu's 96 px MixedMenuIconRenderer artwork.
            let hex = String(entry.appearance.color.dropFirst().prefix(6))
            let rgb = UInt32(hex, radix: 16) ?? 0x2563EB
            iconPNG = SearchableRichSampleCatalog.thumbnail(
                symbol: entry.appearance.icon,
                rgb: rgb
            )
        }

        return SearchableRichSampleEntity(
            id: id,
            name: entry.appearance.title,
            category: category,
            source: source,
            details: details,
            tags: tags,
            subtitle: entry.appearance.subtitle,
            iconPNG: iconPNG
        )
    }
}
