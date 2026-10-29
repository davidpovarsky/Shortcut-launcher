import AppIntents
import Foundation
import SwiftUI
import Translation

// Isolated experiment: does the system-hosted Shortcuts Snippet allow
// SwiftUI's real Apple Translate presentation? No private APIs are used.
// Both buttons target the same native translationPresentation modifier.
private enum TranslationSnippetProbeStore {
    private static let pendingKey = "translationSnippetProbe.pending.v1"

    static func requestPresentation() {
        AppEnvironment.sharedDefaults.set(true, forKey: pendingKey)
    }

    /// Consume once, so unrelated snippet reloads cannot endlessly reopen the popover.
    static func consumePresentationRequest() -> Bool {
        let defaults = AppEnvironment.sharedDefaults
        let pending = defaults.bool(forKey: pendingKey)
        if pending {
            defaults.set(false, forKey: pendingKey)
        }
        return pending
    }
}

/// Supported snippet control: AppIntent-backed Button. The host reruns the
/// SnippetIntent after this action; the refreshed view tries to present Translate.
struct RequestTranslationPopoverSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Request Translate Popover"
    static let description = IntentDescription(
        "Requests the system Apple Translate popover from a Shortcuts-hosted snippet."
    )
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    init() {}

    func perform() async throws -> some IntentResult {
        TranslationSnippetProbeStore.requestPresentation()
        TranslationSnippetExperimentIntent.reload()
        return .result()
    }
}

struct TranslationSnippetExperimentIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Apple Translate Snippet"
    static let description = IntentDescription(
        "Tests whether Apple's native translation popover can open from an interactive Shortcuts snippet."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Text to Translate",
        description: "Text passed to Apple's native Translate interface. Leave blank for a sample sentence."
    )
    var text: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Test Apple Translate with \(\.$text)")
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let supplied = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selectedText = supplied.isEmpty
            ? "Hello! How are you today?"
            : supplied

        return .result(
            view: TranslationSnippetProbeView(
                text: selectedText,
                openAfterReload: TranslationSnippetProbeStore.consumePresentationRequest()
            )
        )
    }
}

private struct TranslationSnippetProbeView: View {
    let text: String
    let openAfterReload: Bool

    @State private var showTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Translate · Snippet Lab", systemImage: "translate")
                .font(.headline)

            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(3)

            Button(intent: RequestTranslationPopoverSnippetIntent()) {
                Label("Open Translate · AppIntent", systemImage: "character.book.closed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                // Deliberate second probe: ordinary Button actions are not
                // promised to work in the Shortcuts snippet host.
                showTranslation = true
            } label: {
                Label("Open Translate · SwiftUI", systemImage: "hand.tap")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(
                openAfterReload
                    ? "AppIntent request received. Attempting native translation popover…"
                    : "Try each button separately. The host may reject modal presentation."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .translationPresentation(isPresented: $showTranslation, text: text)
        .task(id: openAfterReload) {
            guard openAfterReload else { return }
            // Allow the returned snippet to enter the host's view hierarchy
            // before requesting a presentation. The host can still deny it.
            await Task.yield()
            showTranslation = true
        }
    }
}
