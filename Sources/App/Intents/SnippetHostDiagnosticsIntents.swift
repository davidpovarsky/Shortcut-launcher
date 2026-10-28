import AppIntents
import Foundation
import SwiftUI
import WebKit

// A/B test for what the Shortcuts-hosted snippet renderer actually supports.
// Keep these separate from the WebKit test so one unsupported view doesn't
// replace the rest of the snippet with a prohibited-content placeholder.

private enum SnippetHostDiagnosticStore {
    static let counterKey = "snippetHostDiagnosticCounter"

    static var count: Int {
        AppEnvironment.sharedDefaults.integer(forKey: counterKey)
    }

    static func increment() {
        let defaults = AppEnvironment.sharedDefaults
        defaults.set(defaults.integer(forKey: counterKey) + 1, forKey: counterKey)
    }

    static func reset() {
        AppEnvironment.sharedDefaults.set(0, forKey: counterKey)
    }
}

/// App Intents, unlike ordinary SwiftUI onTapGesture, are documented to
/// support interactive snippet controls.
struct IncrementSnippetHostCounterIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Increment Snippet Counter"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    init() {}

    func perform() async throws -> some IntentResult {
        SnippetHostDiagnosticStore.increment()
        NativeSnippetHostDiagnosticIntent.reload()
        return .result()
    }
}

struct ResetSnippetHostCounterIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Reset Snippet Counter"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    init() {}

    func perform() async throws -> some IntentResult {
        SnippetHostDiagnosticStore.reset()
        NativeSnippetHostDiagnosticIntent.reload()
        return .result()
    }
}

/// Positive control: only text, SF Symbols and Buttons backed by App Intents.
/// This should establish that interactive snippets work independently of WebKit.
struct NativeSnippetHostDiagnosticIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Native Snippet Controls"
    static let description = IntentDescription(
        "Tests a real iPadOS interactive snippet with native text and AppIntent buttons."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: NativeSnippetDiagnosticView(count: SnippetHostDiagnosticStore.count))
    }
}

private struct NativeSnippetDiagnosticView: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Native Snippet Test", systemImage: "checkmark.seal")
                .font(.headline)

            Text("The native SwiftUI view rendered successfully.")
                .font(.subheadline)

            Text("Counter: \(count)")
                .font(.title2)
                .bold()

            HStack {
                Button(intent: IncrementSnippetHostCounterIntent()) {
                    Label("Increment", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button(intent: ResetSnippetHostCounterIntent()) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            Text("If the counter updates, native AppIntent buttons work inside the Shortcuts overlay.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

/// Separate probe for the native SwiftUI sharing mechanism. ShareLink works
/// in ordinary app views but is not documented to work in a SnippetIntent.
struct ShareLinkSnippetHostDiagnosticIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Snippet ShareLink"
    static let description = IntentDescription(
        "Tests whether a Shortcuts snippet can open a native share sheet via ShareLink."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: ShareLinkSnippetDiagnosticView())
    }
}

private struct ShareLinkSnippetDiagnosticView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ShareLink Snippet Test", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("The next control is a native SwiftUI ShareLink (not HTML or JavaScript).")
                .font(.subheadline)

            ShareLink(
                "Open Share Sheet",
                item: URL(string: "https://example.org/")!
            )
            .font(.headline)

            Text("If the share control is blocked, iPadOS cannot host this view here. If it works, check whether an extension stays inside the snippet window.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}


// Deliberately tiny variants (< 400 pt) to distinguish an oversized
// WebKit.WebView(page) problem from a host-wide prohibition on web surfaces.
// Keep each in its own SnippetIntent, so one failure doesn't mask another.
struct CompactSwiftUIWebViewDiagnosticIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Compact SwiftUI WebView"
    static let description = IntentDescription(
        "Tests the simple native WebKit WebView(url:) at a 180-point height inside a snippet."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: CompactSwiftUIWebViewDiagnosticView())
    }
}

private struct CompactSwiftUIWebViewDiagnosticView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Native WebKit WebView(url:)")
                .font(.headline)
            WebView(url: URL(string: "https://example.com/"))
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("If a forbidden symbol appears here, the host rejected the compact WebKit view too.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct CompactWKWebViewDiagnosticIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Compact UIKit WKWebView"
    static let description = IntentDescription(
        "Tests the older WKWebView embedded with UIViewRepresentable in a compact snippet."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: CompactWKWebViewDiagnosticView())
    }
}

private struct CompactWKWebViewDiagnosticView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("UIKit WKWebView / UIViewRepresentable")
                .font(.headline)
            WKWebViewWrapper()
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("The embedded page contains a JavaScript counter; no internet connection is required.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

private struct WKWebViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.loadHTMLString(
            #"""
            <!doctype html>
            <html lang="en">
            <head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body style="font:18px -apple-system,system-ui;background:#eff6ff;padding:15px">
              <b>UIKit WKWebView loaded!</b>
              <p>JavaScript counter: <span id="count">0</span></p>
              <button style="font:inherit;padding:10px"
                onclick="document.getElementById('count').textContent = Number(document.getElementById('count').textContent) + 1">
                Increment
              </button>
            </body>
            </html>
            """#,
            baseURL: nil
        )
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
