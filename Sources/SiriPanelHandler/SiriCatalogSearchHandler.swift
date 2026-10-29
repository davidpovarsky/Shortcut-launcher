import Foundation
import Intents

/// SiriKit legacy custom-intent experiment: the Shortcuts editor may call
/// provideEntryOptionsCollection(searchTerm:) on each typed search update.
/// Unlike the Contacts provider, this catalog is local and app-owned.
final class SiriCatalogSearchHandler: NSObject, DavSearchCatalogIntentHandling {

    private struct Sample {
        let id: String
        let title: String
        let subtitle: String
        let tags: String
        let symbol: String

        var searchableText: String {
            [id, title, subtitle, tags].joined(separator: " ")
        }

        func makeObject() -> DavCatalogEntry {
            DavCatalogEntry(
                identifier: id,
                display: title,
                subtitle: subtitle,
                image: INImage.systemImageNamed(symbol)
            )
        }
    }

    // First six are recommended; the remaining entries are especially useful
    // for proving that query-specific suggestions are actually consulted.
    private static let samples: [Sample] = [
        .init(id: "document-annual", title: "דוח פעילות 2026", subtitle: "PDF · 24 pages · demo", tags: "report pdf annual document דוח", symbol: "doc.richtext"),
        .init(id: "note-team", title: "סיכום פגישת צוות", subtitle: "Notes · eight paragraphs · demo", tags: "meeting notes team תזכורת", symbol: "note.text"),
        .init(id: "photo-beach", title: "צילום החוף", subtitle: "JPEG · photo · demo", tags: "image photo beach תמונה", symbol: "photo.fill"),
        .init(id: "audio-idea", title: "הקלטת רעיון", subtitle: "M4A · 01:42 · demo", tags: "sound voice audio recording", symbol: "waveform"),
        .init(id: "article-intents", title: "מדריך App Intents", subtitle: "Web article · demo", tags: "web shortcut app intents", symbol: "globe"),
        .init(id: "task-design", title: "לשפר את העיצוב", subtitle: "Reminder · high priority · demo", tags: "task todo design משימה", symbol: "checkmark.circle"),
        .init(id: "invoice-october", title: "חשבונית אוקטובר", subtitle: "Document · scanned · demo", tags: "invoice receipt billing חשבונית", symbol: "doc.text.viewfinder"),
        .init(id: "design-wireframe", title: "סקיצה: מסך הבית", subtitle: "PNG · wireframe · demo", tags: "design UI mockup layout", symbol: "square.on.square"),
        .init(id: "person-daniel", title: "דניאל לוי", subtitle: "Fictional person · demo", tags: "contact person דניאל", symbol: "person.crop.circle"),
        .init(id: "calendar-meeting", title: "פגישת פיתוח שבועית", subtitle: "Calendar event · demo", tags: "calendar event time", symbol: "calendar"),
        .init(id: "map-promenade", title: "נקודת עניין: טיילת", subtitle: "Location · demo", tags: "map location place", symbol: "mappin.and.ellipse"),
        .init(id: "mail-message", title: "טיוטת הודעת פתיחה", subtitle: "Email draft · demo", tags: "mail message inbox email", symbol: "envelope.fill"),
        .init(id: "video-tour", title: "סרטון הדרכת ממשק", subtitle: "MP4 · video · demo", tags: "video tutorial movie mp4", symbol: "video.fill"),
        .init(id: "folder-archive", title: "ארכיון מסמכי פרויקט", subtitle: "Folder · 18 items · demo", tags: "folder archive files", symbol: "folder.fill"),
        .init(id: "book-torah", title: "מקור לימוד: פרשת השבוע", subtitle: "Book · Hebrew study · demo", tags: "sefaria torah parsha ספר", symbol: "books.vertical.fill"),
        .init(id: "recipe-grandma", title: "כרטיס מתכון משפחתי", subtitle: "Recipe card · demo", tags: "recipe food cook grandma מתכון", symbol: "fork.knife")
    ]

    private static func matches(_ sample: Sample, searchTerm: String?) -> Bool {
        guard let searchTerm,
              !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        let terms = searchTerm.split(whereSeparator: { $0.isWhitespace })
        return terms.allSatisfy { sample.searchableText.localizedStandardContains(String($0)) }
    }

    func provideEntryOptionsCollection(
        for intent: DavSearchCatalogIntent,
        searchTerm: String?,
        with completion: @escaping (INObjectCollection<DavCatalogEntry>?, Error?) -> Void
    ) {
        // Log when SiriKit actually requests each search term on the device.
        NSLog("Dav SiriKit search: requested term=%@", searchTerm ?? "<suggestions>")
        let matches = Self.samples.filter { Self.matches($0, searchTerm: searchTerm) }
        let selected = searchTerm?.isEmpty == false
            ? Array(matches.prefix(30))
            : Array(matches.prefix(6))
        completion(INObjectCollection(items: selected.map { $0.makeObject() }), nil)
    }

    func resolveEntry(
        for intent: DavSearchCatalogIntent,
        with completion: @escaping (DavCatalogEntryResolutionResult) -> Void
    ) {
        guard let entry = intent.entry else {
            completion(.needsValue())
            return
        }
        guard let sample = Self.samples.first(where: { $0.id == entry.identifier }) else {
            completion(.unsupported())
            return
        }
        completion(.success(with: sample.makeObject()))
    }

    func handle(
        intent: DavSearchCatalogIntent,
        completion: @escaping (DavSearchCatalogIntentResponse) -> Void
    ) {
        guard let entry = intent.entry,
              Self.samples.contains(where: { $0.id == entry.identifier }) else {
            NSLog("Dav SiriKit search: no valid selection")
            completion(DavSearchCatalogIntentResponse(code: .failure, userActivity: nil))
            return
        }
        NSLog("Dav SiriKit search: selected=%@", entry.identifier ?? "<missing>")
        let activity = NSUserActivity(activityType: "com.dav.DavLauncher.sirikitCatalogSelected")
        activity.title = "Selected \(entry.displayString)"
        activity.userInfo = [
            "identifier": entry.identifier ?? "",
            "title": entry.displayString
        ]
        completion(DavSearchCatalogIntentResponse(code: .success, userActivity: activity))
    }
}
