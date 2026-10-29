import AppIntents
import Foundation
import UIKit

/// Persistent, synthetic objects for testing Shortcuts' EDITOR-TIME searchable
/// AppEntity picker. These are not actual Files, Contacts, Photos or Mail items.
struct SearchableRichSampleEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rich Demo Object")
    static let defaultQuery = SearchableRichSampleQuery()

    let id: String

    let name: String

    let category: String

    let source: String

    let details: String

    let tags: String

    let subtitle: String
    let iconPNG: Data

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(subtitle)",
            image: DisplayRepresentation.Image(
                data: iconPNG,
                isTemplate: false,
                displayStyle: .default
            )
        )
    }

    var searchableText: String {
        [name, subtitle, category, source, details, tags].joined(separator: " ")
    }
}

/// Shortcuts uses suggestedEntities for its initial suggestions, and
/// entities(matching:) for a real text search across the WHOLE catalog.
struct SearchableRichSampleQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SearchableRichSampleEntity] {
        let all = await SearchableRichSampleCatalog.entities
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0] }
    }

    func suggestedEntities() async throws -> [SearchableRichSampleEntity] {
        Array((await SearchableRichSampleCatalog.entities).prefix(7))
    }

    func entities(matching string: String) async throws -> [SearchableRichSampleEntity] {
        let all = await SearchableRichSampleCatalog.entities
        let terms = string.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return Array(all.prefix(7)) }
        return all.filter { entity in
            terms.allSatisfy { entity.searchableText.localizedStandardContains($0) }
        }
    }
}

/// Render the thumbnails once on the main actor; the query returns cached
/// Sendable value objects, so no Contacts/Photos/Files permissions are used.
@MainActor
private enum SearchableRichSampleCatalog {
    private typealias Sample = (
        id: String, name: String, subtitle: String, category: String,
        source: String, details: String, tags: String,
        symbol: String, color: UInt32
    )

    // First seven are suggestions; the remainder are discoverable by SEARCH.
    // Every record is deliberately fictional, even when its source resembles
    // a system or third-party app.
    private static let samples: [Sample] = [
        ("report", "דוח פעילות 2026", "PDF · 24 עמודים · דוגמה", "מסמך", "קבצים · דוגמה", "דוח שנתי מדומה עם נתונים ותרשימים", "דוח PDF annual report 2026", "doc.richtext", 0x2563EB),
        ("team-note", "סיכום פגישת צוות", "הערה · 8 פסקאות · דוגמה", "הערה", "פתקים · דוגמה", "סיכום החלטות ממשק וצעדים הבאים", "notes meeting team פגישה", "note.text", 0x7C3AED),
        ("beach-photo", "צילום החוף", "תמונה · JPEG · דוגמה", "תמונה", "תמונות · דוגמה", "צילום נוף עם תאריך ומיקום מדומים", "photo beach תמונה ים", "photo.fill", 0x0891B2),
        ("voice-memo", "הקלטת רעיון לעיצוב", "אודיו · M4A · 01:42 · דוגמה", "אודיו", "הקלטות · דוגמה", "הקלטה קצרה של רעיון לממשק", "audio voice record שמע", "waveform", 0xDB2777),
        ("web-article", "מדריך App Intents", "קישור · מאמר טכני · דוגמה", "קישור", "דפדפן · דוגמה", "רשומת דוגמה על פעולות ופרמטרים", "web article shortcut appintents", "globe", 0x0D9488),
        ("todo-design", "משימה: לשפר את העיצוב", "משימה · עדיפות גבוהה · דוגמה", "משימה", "תזכורות · דוגמה", "משימה לדוגמה עם תיאור ותגיות", "task reminder priority ui", "checkmark.circle.fill", 0xEA580C),
        ("book-study", "ספר: מבוא ל-Swift", "ספר · פרק 4 · דוגמה", "ספר", "ספרייה · דוגמה", "פריט קריאה מדומה בספרייה", "book swift learning ספר", "books.vertical.fill", 0x4F46E5),
        ("invoice", "חשבונית אוקטובר", "סריקה · עמוד אחד · דוגמה", "מסמך", "קבצים · דוגמה", "חשבונית מדומה לצורך בדיקת חיפוש", "invoice receipt scan חשבונית", "doc.text.viewfinder", 0x475569),
        ("wireframe", "סקיצה: מסך הבית", "תמונה · PNG · דוגמה", "עיצוב", "קבצים · דוגמה", "סקיצה גרפית מדומה של ממשק אפליקציה", "design wireframe mockup ui", "square.on.square", 0x9333EA),
        ("person", "דניאל לוי", "איש קשר · דוגמה בלבד", "איש קשר", "אנשי קשר · דוגמה", "רשומת קשר בדיונית; לא נוספה למכשיר", "contact person mail דניאל", "person.crop.circle.fill", 0x0284C7),
        ("meeting", "פגישת פיתוח שבועית", "אירוע · 10:00 · דוגמה", "אירוע", "לוח שנה · דוגמה", "אירוע מדומה, אינו שמור ביומן", "calendar schedule meeting אירוע", "calendar", 0x16A34A),
        ("map-pin", "נקודת עניין: טיילת", "מיקום · דוגמה", "מיקום", "מפות · דוגמה", "נקודת ציון בדיונית לצורך חיפוש", "location map place חוף", "mappin.and.ellipse", 0xCA8A04),
        ("mail-draft", "טיוטת הודעת פתיחה", "הודעת דוא״ל · דוגמה", "דוא״ל", "דואר · דוגמה", "הודעה לדוגמה; לא נקראה מתיבת דואר", "mail email draft דואר", "envelope.fill", 0x0F766E),
        ("video-demo", "סרטון הדרכת ממשק", "וידאו · MP4 · 00:38 · דוגמה", "וידאו", "תמונות · דוגמה", "וידאו מדומה להדגמת שורת תוצאה", "video movie tutorial", "video.fill", 0xBE123C),
        ("archive", "ארכיון מסמכי פרויקט", "תיקייה · 18 פריטים · דוגמה", "תיקייה", "קבצים · דוגמה", "תיקיית דוגמה עם מטא-נתונים", "folder archive files תיקיה", "folder.fill", 0xB45309),
        ("sefaria", "מקור לימוד: פרשת השבוע", "טקסט · מקור לימוד · דוגמה", "טקסט", "ספרייה · דוגמה", "פריט דוגמה בעברית, ללא גישה למאגר חיצוני", "sefaria parsha torah לימוד", "text.book.closed.fill", 0x0F766E)
    ]

    static let entities: [SearchableRichSampleEntity] = samples.map { sample in
        SearchableRichSampleEntity(
            id: sample.id,
            name: sample.name,
            category: sample.category,
            source: sample.source,
            details: sample.details,
            tags: sample.tags,
            subtitle: sample.subtitle,
            iconPNG: thumbnail(symbol: sample.symbol, rgb: sample.color)
        )
    }

    private static func thumbnail(symbol: String, rgb: UInt32) -> Data {
        let size: CGFloat = 88
        let color = UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).pngData { _ in
            color.setFill()
            UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                cornerRadius: 20
            ).fill()

            let configuration = UIImage.SymbolConfiguration(pointSize: 43, weight: .medium)
            guard let image = UIImage(
                systemName: symbol,
                withConfiguration: configuration
            )?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return
            }
            let scale = min(49 / max(image.size.width, 1), 49 / max(image.size.height, 1))
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(in: CGRect(
                x: (size - width) / 2,
                y: (size - height) / 2,
                width: width,
                height: height
            ))
        }
    }
}

/// Test the parameter INSIDE the Shortcuts editor: tap "Rich Object" to
/// see native suggestions, then type into the system's search field.
struct SearchableRichObjectIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Searchable Rich Objects"
    static let description = IntentDescription(
        "Pick a rich fictional object with a system search field; returns its typed AppEntity and metadata."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Rich Object", requestValueDialog: "Choose a demo object")
    var object: SearchableRichSampleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$object) in the searchable examples")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<SearchableRichSampleEntity> {
        .result(value: object)
    }
}
