import SwiftUI

struct SefariaSearchView: View {
    let request: SpotlightSearchRequest

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var items: [SefariaPreviewItem] = []
    @State private var resultCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastCompletedQuery = ""
    @FocusState private var queryFieldFocused: Bool

    init(request: SpotlightSearchRequest) {
        self.request = request
        _query = State(initialValue: request.query)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                Divider()
                resultsContent
            }
            .navigationTitle("Sefaria Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: request.id) {
            await runSearch()
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search Sefaria", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($queryFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await runSearch() }
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        items = []
                        resultCount = 0
                        errorMessage = nil
                        queryFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }

                Button {
                    Task { await runSearch() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Search")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || trimmedQuery.isEmpty)
            }
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 6) {
                Image(systemName: "sparkle.magnifyingglass")
                Text("Query received from Spotlight")
                Text("•")
                Text(request.source.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private var resultsContent: some View {
        if isLoading && items.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                Text("Searching Sefaria…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Search Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await runSearch() }
                }
            }
        } else if items.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "text.magnifyingglass",
                description: Text(lastCompletedQuery.isEmpty ? "Enter a search term." : "Sefaria returned no matches for “\(lastCompletedQuery)”.")
            )
        } else {
            List {
                Section {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)
                                .textSelection(.enabled)

                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            if !item.excerpt.isEmpty {
                                Text(item.excerpt)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(5)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                } header: {
                    HStack {
                        Text("Results")
                        Spacer()
                        Text("\(resultCount) found • showing \(items.count)")
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await runSearch()
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func runSearch() async {
        let requestedQuery = trimmedQuery
        guard !requestedQuery.isEmpty else {
            items = []
            resultCount = 0
            lastCompletedQuery = ""
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        DiagnosticLog.record(
            "spotlight.searchContinuation.search.started",
            details: [
                "query": requestedQuery,
                "source": request.source.rawValue,
                "requestID": request.id.uuidString
            ]
        )

        do {
            let payload = try await SefariaSpotlightAPI.loadPreview(
                identifier: SefariaSpotlightLab.generalSearchIdentifier,
                rawQuery: requestedQuery
            )

            guard trimmedQuery == requestedQuery else { return }

            items = payload.items
            resultCount = payload.resultCount
            lastCompletedQuery = requestedQuery
            isLoading = false

            DiagnosticLog.record(
                "spotlight.searchContinuation.search.completed",
                details: [
                    "query": requestedQuery,
                    "resultCount": String(payload.resultCount),
                    "shownCount": String(payload.items.count),
                    "requestID": request.id.uuidString
                ]
            )
            DiagnosticLog.syncSharedLogToDocuments()
        } catch {
            guard trimmedQuery == requestedQuery else { return }

            items = []
            resultCount = 0
            lastCompletedQuery = requestedQuery
            isLoading = false
            errorMessage = error.localizedDescription

            DiagnosticLog.record(
                "spotlight.searchContinuation.search.failed",
                details: [
                    "query": requestedQuery,
                    "error": String(describing: error),
                    "requestID": request.id.uuidString
                ]
            )
            DiagnosticLog.syncSharedLogToDocuments()
        }
    }
}
