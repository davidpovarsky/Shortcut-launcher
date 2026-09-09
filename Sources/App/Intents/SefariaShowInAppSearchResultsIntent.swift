import AppIntents

struct SefariaShowInAppSearchResultsIntent: ShowInAppSearchResultsIntent {
    static var searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    func perform() async throws -> some IntentResult {
        let query = criteria.term
        await MainActor.run {
            SpotlightSearchCoordinator.shared.present(query: query, source: .appIntent)
        }
        return .result()
    }
}
