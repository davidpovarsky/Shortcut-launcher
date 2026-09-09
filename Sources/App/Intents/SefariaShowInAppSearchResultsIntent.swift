import AppIntents

struct SefariaShowInAppSearchResultsIntent: ShowInAppSearchResultsIntent {
    static let title: LocalizedStringResource = "Search Sefaria"
    static let searchScopes: [StringSearchScope] = [.general]

    @Parameter var criteria: StringSearchCriteria

    func perform() async throws -> some IntentResult {
        let query = criteria.term
        await MainActor.run {
            SpotlightSearchCoordinator.shared.present(query: query, source: .appIntent)
        }
        return .result()
    }
}
