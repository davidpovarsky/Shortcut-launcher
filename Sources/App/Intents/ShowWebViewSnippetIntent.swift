import AppIntents
import Foundation
import SwiftUI
import WebKit

/// Experimental iOS 26+ SnippetIntent that embeds the native SwiftUI WebKit
/// WebView. The host (Shortcuts/Siri/Spotlight) controls the snippet's actual
/// window size, rendering support and whether web-initiated sheets are allowed.
struct ShowWebViewSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Live WebView Snippet"
    static let description = IntentDescription(
        "Experimentally displays an interactive WebKit browser inside an App Intent snippet. Supply HTTPS URL or HTML; leave blank for the test page."
    )
    // A view-only SnippetIntent is hidden from Shortcuts unless explicitly enabled.
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "HTML or Website URL",
        description: "Pass HTML markup or an http(s) URL. Leave empty to test JavaScript, a file picker and the share sheet."
    )
    var source: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Show live WebView from \(\.$source)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: LiveWebSnippetView(source: source ?? ""))
    }
}

enum LiveWebSnippetSource {
    static func webURL(from source: String) -> URL? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return nil
        }
        return url
    }

    static func html(from source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? demoHTML
            : source
    }

    static let demoHTML = #"""
    <!doctype html>
    <html lang="he" dir="rtl">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>DavLauncher WebView Snippet</title>
    <style>
      * { box-sizing: border-box; }
      body { margin:0; padding:18px; font:16px -apple-system,system-ui,sans-serif;
             background:#f7f8fc; color:#182237; }
      h2 { margin:0 0 6px; font-size:21px; }
      p { margin:0 0 14px; color:#657086; font-size:13px; line-height:1.55; }
      button, input { font:inherit; }
      button { width:100%; padding:13px; border:0; border-radius:12px;
               background:#087aff; color:white; margin:7px 0; }
      label { display:block; padding:14px; background:white; border:1px solid #d6dbe5;
              border-radius:12px; margin:7px 0; text-align:center; }
      input[type=file] { width:100%; font-size:13px; }
      input[type=text] { width:100%; padding:13px; border-radius:12px;
                         border:1px solid #d6dbe5; }
      #log { margin-top:12px; padding:12px; border-radius:12px; background:#e9edf6;
             font-size:12px; white-space:pre-wrap; overflow-wrap:anywhere; }
    </style>
    </head>
    <body>
      <h2>WebView בתוך Snippet</h2>
      <p>בדיקה: לחיצות, JavaScript, בורר קבצים וגיליון שיתוף.</p>
      <button id="count">לחיצה חיה: 0</button>
      <label>בורר קבצים מקורי<input id="file" type="file"></label>
      <input id="entry" type="text" placeholder="שדה הקלדה חי">
      <button id="share">בדוק navigator.share()</button>
      <div id="log">JavaScript עדיין לא פעל.</div>
      <script>
        const log = document.getElementById('log');
        log.textContent = 'JavaScript עובד. navigator.share: ' +
          (typeof navigator.share === 'function' ? 'זמין' : 'לא זמין');
        let clicks = 0;
        document.getElementById('count').onclick = () => {
          document.getElementById('count').textContent = 'לחיצה חיה: ' + (++clicks);
        };
        document.getElementById('file').onchange = (e) => {
          log.textContent = 'קובץ: ' + (e.target.files[0]?.name ?? 'לא נבחר');
        };
        document.getElementById('share').onclick = async () => {
          try {
            if (!navigator.share) throw new Error('Web Share API אינו זמין');
            await navigator.share({text:'WebView from DavLauncher Snippet'});
            log.textContent = 'השיתוף הושלם';
          } catch (error) {
            log.textContent = error.name + ': ' + error.message;
          }
        };
      </script>
    </body>
    </html>
    """#
}

/// A real WebKit browser, not a screenshot or an HTML-to-Text conversion.
/// Apple's snippet host may cap its size or omit unsupported controls.
private struct LiveWebSnippetView: View {
    let source: String

    @State private var page = WebPage()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("WebKit Snippet Experiment", systemImage: "globe")
                .font(.headline)

            WebView(page)
                .frame(maxWidth: .infinity)
                .frame(height: 460)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Native WebKit view · Shortcuts controls the snippet window size")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .task(id: source) {
            if let url = LiveWebSnippetSource.webURL(from: source) {
                _ = page.load(url)
            } else {
                _ = page.load(html: LiveWebSnippetSource.html(from: source))
            }
        }
    }
}
