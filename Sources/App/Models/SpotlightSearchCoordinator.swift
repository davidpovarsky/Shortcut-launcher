import Combine
import CoreSpotlight
import Foundation

struct SpotlightSearchRequest: Identifiable, Equatable, Sendable {
    enum Source: String, Sendable {
        case appDelegate = "UIApplicationDelegate continuation"
        case swiftUIScene = "SwiftUI scene continuation"
        case appIntent = "ShowInAppSearchResultsIntent"
    }

    let id: UUID
    let query: String
    let source: Source
    let receivedAt: Date
}

@MainActor
final class SpotlightSearchCoordinator: ObservableObject {
    static let shared = SpotlightSearchCoordinator()

    @Published var activeRequest: SpotlightSearchRequest?

    private init() {}

    @discardableResult
    func receive(userActivity: NSUserActivity, source: SpotlightSearchRequest.Source) -> Bool {
        guard userActivity.activityType == CSQueryContinuationActionType else {
            return false
        }

        guard let rawQuery = userActivity.userInfo?[CSSearchQueryString] as? String else {
            DiagnosticLog.record(
                "spotlight.searchContinuation.missingQuery",
                details: ["source": source.rawValue]
            )
            return false
        }

        present(query: rawQuery, source: source)
        return true
    }

    func present(query rawQuery: String, source: SpotlightSearchRequest.Source) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            DiagnosticLog.record(
                "spotlight.searchContinuation.emptyQuery",
                details: ["source": source.rawValue]
            )
            return
        }

        if activeRequest?.query == query {
            DiagnosticLog.record(
                "spotlight.searchContinuation.duplicateIgnored",
                details: ["query": query, "source": source.rawValue]
            )
            return
        }

        let request = SpotlightSearchRequest(
            id: UUID(),
            query: query,
            source: source,
            receivedAt: Date()
        )
        activeRequest = request

        DiagnosticLog.record(
            "spotlight.searchContinuation.presented",
            details: [
                "query": query,
                "source": source.rawValue,
                "requestID": request.id.uuidString
            ]
        )
        DiagnosticLog.syncSharedLogToDocuments()
    }

    func dismiss() {
        guard let request = activeRequest else { return }
        DiagnosticLog.record(
            "spotlight.searchContinuation.dismissed",
            details: [
                "query": request.query,
                "source": request.source.rawValue,
                "requestID": request.id.uuidString
            ]
        )
        activeRequest = nil
        DiagnosticLog.syncSharedLogToDocuments()
    }
}
