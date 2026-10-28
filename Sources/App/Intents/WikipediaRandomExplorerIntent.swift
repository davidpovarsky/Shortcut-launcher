import AppIntents
import Foundation
import SwiftUI
import UIKit

// MARK: - A native multi-step Wikipedia explorer for Shortcuts
//
// One parent App Intent remains suspended while iPadOS presents a confirmation
// snippet. "חפש שוב" is the system's deny button, deliberately caught here to
// request another real random article. "פתח" accepts and returns the URL.
//
// IMPORTANT: Catching confirmation cancellation to continue a Shortcut is an
// experimentally verified iPadOS 27 behavior, not a supported Apple guarantee.
// The preexisting Back/Next confirmation lab proved it on the user's iPad.

struct WikipediaRandomExplorerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Wikipedia Discovery"
    static let description = IntentDescription(
        "Browse real random Hebrew Wikipedia articles in a native snippet. חפש שוב loads a new article; פתח returns the article URL to Shortcuts."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<URL> {
        let sessionID = UUID().uuidString
        defer { WikipediaSnippetArticleStore.remove(sessionID: sessionID) }

        var previousIDs = Set<Int>()

        // Bound the intentionally caught cancellation loop to prevent
        // uncontrolled network traffic if a host starts rejecting prompts.
        for resultNumber in 1...60 {
            try Task.checkCancellation()
            let article = try await WikipediaRandomArticleAPI.fetch(excluding: previousIDs)
            previousIDs.insert(article.pageID)
            WikipediaSnippetArticleStore.save(article, sessionID: sessionID, number: resultNumber)

            do {
                // System presents the article snippet and TWO NATIVE buttons:
                // confirm = "פתח" (return URL), deny = "חפש שוב" (retry loop).
                try await requestConfirmation(
                    actionName: .custom(
                        acceptLabel: "פתח",
                        acceptAlternatives: [],
                        denyLabel: "חפש שוב",
                        denyAlternatives: [],
                        destructive: false
                    ),
                    dialog: "גלה ערך אקראי מוויקיפדיה",
                    showDialogAsPrompt: false,
                    snippetIntent: WikipediaArticleSnippetIntent(sessionID: sessionID)
                )

                WikipediaSnippetArticleStore.noteAction(
                    "open: \(article.pageID)",
                    sessionID: sessionID
                )
                return .result(value: article.url)
            } catch {
                // The earlier Back/Next lab confirmed on iPadOS 27 that an
                // intentionally caught denial can keep the parent Shortcut
                // running. Apple does not guarantee this on other OS versions.
                if Task.isCancelled { throw error }
                WikipediaSnippetArticleStore.noteAction(
                    "retry after confirmation denied: \(String(reflecting: type(of: error)))",
                    sessionID: sessionID
                )
            }
        }

        throw WikipediaExplorerError.tooManyAttempts
    }
}

/// This is a true SnippetIntent, not WebKit and not a screenshot.
/// It is shown by the parent requestConfirmation(snippetIntent:) call.
struct WikipediaArticleSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Wikipedia Article Preview"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Discovery Session")
    var sessionID: String

    init() {}

    init(sessionID: String) {
        self.sessionID = sessionID
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let stored = WikipediaSnippetArticleStore.load(sessionID: sessionID)
        return .result(view: WikipediaArticleSnippetView(stored: stored))
    }
}

// MARK: - Wikipedia API

struct WikipediaRandomArticle: Codable, Sendable {
    let pageID: Int
    let title: String
    let excerpt: String
    let url: URL
    let thumbnailData: Data?
}

struct WikipediaArticleSnapshot: Codable, Sendable {
    let article: WikipediaRandomArticle
    let number: Int
}

enum WikipediaExplorerError: LocalizedError {
    case invalidResponse
    case unavailable
    case tooManyAttempts
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Wikipedia returned an invalid article."
        case .unavailable:
            return "Could not load a suitable Wikipedia article. Try the action again."
        case .tooManyAttempts:
            return "The discovery session reached its safety limit of 60 articles."
        case .httpStatus(let status):
            return "Wikipedia request failed (HTTP \(status))."
        }
    }
}

private struct WikipediaAPIEnvelope: Decodable {
    struct Query: Decodable {
        let pages: [Page]?
    }

    struct Page: Decodable {
        struct Thumbnail: Decodable {
            let source: URL
        }

        let pageid: Int
        let title: String
        let extract: String?
        let fullurl: URL?
        let thumbnail: Thumbnail?
    }

    let query: Query?
}

enum WikipediaRandomArticleAPI {
    static let userAgent =
        "DavLauncher/1.1 (https://github.com/davidpovarsky/Shortcut-launcher; iPad Shortcuts Wikipedia discovery)"

    static func makeRequest() -> URLRequest {
        var components = URLComponents(string: "https://he.wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "random"),
            URLQueryItem(name: "grnnamespace", value: "0"),
            URLQueryItem(name: "grnminsize", value: "2000"),
            URLQueryItem(name: "grnlimit", value: "1"),
            URLQueryItem(name: "prop", value: "extracts|pageimages|info"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "pithumbsize", value: "320"),
            URLQueryItem(name: "inprop", value: "url"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "probe", value: UUID().uuidString)
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func decode(_ data: Data) throws -> WikipediaRandomArticle {
        guard let envelope = try? JSONDecoder().decode(WikipediaAPIEnvelope.self, from: data),
              let page = envelope.query?.pages?.first,
              let url = page.fullurl,
              url.scheme?.lowercased() == "https",
              url.host == "he.wikipedia.org" else {
            throw WikipediaExplorerError.invalidResponse
        }

        let cleaned = (page.extract ?? "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !page.title.isEmpty, cleaned.count >= 80 else {
            throw WikipediaExplorerError.invalidResponse
        }

        let excerpt = String(cleaned.prefix(430))
        return WikipediaRandomArticle(
            pageID: page.pageid,
            title: page.title,
            excerpt: excerpt,
            url: url,
            thumbnailData: nil
        )
    }

    static func fetch(excluding previousIDs: Set<Int>) async throws -> WikipediaRandomArticle {
        // Skip very short / redirect / repeated random pages.
        // A few attempts are expected because Wikipedia includes stub articles.
        for _ in 0..<8 {
            try Task.checkCancellation()
            let (data, response) = try await URLSession.shared.data(for: makeRequest())
            guard let http = response as? HTTPURLResponse else {
                throw WikipediaExplorerError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                throw WikipediaExplorerError.httpStatus(http.statusCode)
            }
            guard let article = try? decode(data),
                  !previousIDs.contains(article.pageID) else {
                continue
            }

            // Images are downloaded before presentation so the system-hosted
            // snippet can render them synchronously (no AsyncImage/WebView).
            let image = await imageForPage(data: data)
            return WikipediaRandomArticle(
                pageID: article.pageID,
                title: article.title,
                excerpt: article.excerpt,
                url: article.url,
                thumbnailData: image
            )
        }
        throw WikipediaExplorerError.unavailable
    }

    private static func imageForPage(data: Data) async -> Data? {
        guard let envelope = try? JSONDecoder().decode(WikipediaAPIEnvelope.self, from: data),
              let imageURL = envelope.query?.pages?.first?.thumbnail?.source,
              imageURL.scheme?.lowercased() == "https",
              let host = imageURL.host?.lowercased(),
              (host == "wikimedia.org" || host.hasSuffix(".wikimedia.org")
                  || host == "wikipedia.org" || host.hasSuffix(".wikipedia.org")) else {
            return nil
        }

        var request = URLRequest(url: imageURL)
        request.timeoutInterval = 7
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (bytes, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  bytes.count <= 550_000,
                  bytes.count > 0 else {
                return nil
            }
            return bytes
        } catch {
            return nil
        }
    }
}

// MARK: - Per-session data for the SnippetIntent host

enum WikipediaSnippetArticleStore {
    static let prefix = "lab.wikipediaArticle.session."
    static let lastActionKey = "lab.wikipediaArticle.lastAction"

    static func save(_ article: WikipediaRandomArticle, sessionID: String, number: Int) {
        let snapshot = WikipediaArticleSnapshot(article: article, number: number)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppEnvironment.sharedDefaults.set(data, forKey: prefix + sessionID)
    }

    static func load(sessionID: String) -> WikipediaArticleSnapshot? {
        guard let data = AppEnvironment.sharedDefaults.data(forKey: prefix + sessionID) else {
            return nil
        }
        return try? JSONDecoder().decode(WikipediaArticleSnapshot.self, from: data)
    }

    static func remove(sessionID: String) {
        AppEnvironment.sharedDefaults.removeObject(forKey: prefix + sessionID)
    }

    static func noteAction(_ action: String, sessionID: String) {
        AppEnvironment.sharedDefaults.set(
            "\(sessionID): \(action)",
            forKey: lastActionKey
        )
    }
}

// MARK: - Article card shown inside native confirmation panel

private struct WikipediaArticleSnippetView: View {
    let stored: WikipediaArticleSnapshot?

    var body: some View {
        if let stored {
            articleCard(stored)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("ויקיפדיה", systemImage: "books.vertical")
                    .font(.headline)
                Text("לא ניתן לטעון את תצוגת הערך")
                    .font(.subheadline)
                Text("נסה להריץ מחדש את הפעולה בקיצורי הדרך.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private func articleCard(_ snapshot: WikipediaArticleSnapshot) -> some View {
        let article = snapshot.article

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ויקיפדיה")
                        .font(.headline)
                    Text("לגלות משהו חדש")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("גילוי #\(snapshot.number)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(article.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)

                    Text(article.excerpt)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .lineLimit(7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let thumbnailData = article.thumbnailData,
                   let image = UIImage(data: thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 122, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("תמונה מתוך ערך ויקיפדיה")
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.blue)
                        .frame(width: 86, height: 100)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                Text("חפש שוב — ערך חדש")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.blue)
                Text("פתח — החזר קישור")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        }
        .padding(17)
        .frame(maxWidth: 560)
    }
}
