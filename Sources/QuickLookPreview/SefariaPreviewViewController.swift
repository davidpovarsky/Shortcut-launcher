import QuickLook
import SwiftUI
import UIKit

@MainActor
final class SefariaPreviewViewController: UIViewController, QLPreviewingController {
    private var hostingController: UIHostingController<SefariaPreviewView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        install(state: .loading(query: "Waiting for Spotlight query…"))
        DiagnosticLog.recordEnvironment("quicklook.sefaria.viewDidLoad")
    }

    nonisolated func preparePreviewOfSearchableItem(
        identifier: String,
        queryString: String?,
        completionHandler handler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                handler(NSError(
                    domain: "DavLauncherSefariaPreview",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Preview controller was released before preparation completed."]
                ))
                return
            }

            SefariaSpotlightLab.recordPreviewStart(identifier: identifier, query: queryString)
            install(state: .loading(query: queryString ?? "No query supplied"))

            do {
                let payload = try await SefariaSpotlightAPI.loadPreview(
                    identifier: identifier,
                    rawQuery: queryString
                )
                SefariaSpotlightLab.recordPreviewSuccess(payload)
                install(state: .loaded(payload))
                handler(nil)
            } catch {
                SefariaSpotlightLab.recordPreviewFailure(
                    identifier: identifier,
                    query: queryString,
                    error: error
                )
                install(
                    state: .failed(
                        query: queryString ?? "",
                        message: error.localizedDescription
                    )
                )
                // The preview itself explains the failure, so tell Quick Look
                // that our view is ready instead of replacing it with a generic error.
                handler(nil)
            }
        }
    }

    private func install(state: SefariaPreviewView.State) {
        let host = UIHostingController(rootView: SefariaPreviewView(state: state))
        host.view.backgroundColor = .clear

        if let existing = hostingController {
            existing.willMove(toParent: nil)
            existing.view.removeFromSuperview()
            existing.removeFromParent()
        }

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }
}

struct SefariaPreviewView: View {
    enum State {
        case loading(query: String)
        case loaded(SefariaPreviewPayload)
        case failed(query: String, message: String)
    }

    let state: State

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                Divider()
                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemBackground))
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text("Sefaria Live Preview")
                    .font(.title2.weight(.semibold))
                Text("Quick Look + Core Spotlight experiment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading(let query):
            VStack(alignment: .leading, spacing: 14) {
                ProgressView()
                Text("Fetching live data from Sefaria…")
                    .font(.headline)
                queryBlock(label: "Spotlight query", value: query)
                Text("Quick Look keeps this preview open while the extension performs the network request.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .failed(let query, let message):
            VStack(alignment: .leading, spacing: 14) {
                Label("Preview could not load", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                queryBlock(label: "Spotlight query", value: query.isEmpty ? "Not supplied" : query)
                Text(message)
                    .font(.body)
                    .textSelection(.enabled)
                Text("Open Dav Launcher → Settings → Spotlight + Sefaria Lab, then inspect the shared diagnostic log for the full request trace.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .loaded(let payload):
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payload.modeTitle)
                            .font(.headline)
                        Text("\(payload.resultCount) matching results reported")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "network")
                        .foregroundStyle(.secondary)
                }

                queryBlock(label: "Spotlight query", value: payload.rawQuery)
                if payload.rawQuery != payload.effectiveQuery {
                    queryBlock(label: "Sent to Sefaria API", value: payload.effectiveQuery)
                }

                if payload.items.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "magnifyingglass",
                        description: Text("The live API request succeeded but returned no preview items.")
                    )
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(payload.items.enumerated()), id: \.element.id) { index, item in
                            resultRow(number: index + 1, item: item)
                        }
                    }
                }

                Text("Live data is fetched only when Spotlight asks the Quick Look extension to prepare this preview.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queryBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "(empty)" : value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func resultRow(number: Int, item: SefariaPreviewItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.excerpt)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
