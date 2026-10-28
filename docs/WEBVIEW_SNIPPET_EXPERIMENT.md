# Live WebView Snippet (experimental)

Branch: experiment/shortcuts-share-extension-invocation
Minimum OS: iOS/iPadOS 27 (project target); Apple's SnippetIntent and SwiftUI WebKit WebView exist from iOS 26.

## Goal

Determine whether the Shortcuts-hosted App Intents snippet renderer can display a **real interactive SwiftUI WebKit WebView**, including JS, keyboard, the native document picker, and Web Share API sheets, without leaving the system overlay.

The public SDK supports SnippetIntent and WebView independently. There is **no demonstrated guarantee** that the system's snippet renderer will preserve this embedded WebView, its requested height, keyboard, or dialogs.

## Action

**LAB: Live WebView Snippet** (visible in Shortcuts thanks to isDiscoverable = true).

The optional **HTML or Website URL** text parameter works as follows:
- Blank: load an embedded interactive test HTML page.
- A string that parses as an HTTP/HTTPS URL: load the page in WebKit.
- Any other string: treat as literal HTML.

The action is discoverable without an AppShortcut tile because this app already uses the maximum ten tile registrations. XcodeGen includes the new file automatically via Sources/App.

## Test on iPad

1. Build and install a signed version of this branch; launch DavLauncher once.
2. In Shortcuts, add Dav Launcher -> LAB: Live WebView Snippet.
3. Leave the source blank. Run. Check whether a visible browser appears rather than only the SwiftUI header.
4. Tap "לחיצה חיה: 0" twice. It should become 2 if HTML/JS interaction works.
5. Tap the file picker. Does it show Files *inside the snippet overlay*? Does the panel survive dismissal?
6. Tap Share. Observe navigator.share availability, permission errors, and whether a Share Extension remains inside the overlay.
7. Repeat with a trusted HTTPS URL, then supplied HTML. Observe keyboard focus, scrolling, and landscape vs portrait.
8. Compare with a native SwiftUI snippet button if the WebView is blank.

## Interpretation

- Header visible, WebView blank: action and snippet registered, WebView not rendered by host.
- WebView visible, JS counter fails: browser may be snapshot-only or events blocked.
- File picker works: web-to-native picker presentation works in this context.
- Share API blocked: inspect secure-context/origin, Web Share permission policy, and host presentation restrictions before concluding that JavaScript is disabled.
- Requested 460-pt WebView height is **not** a full-screen entitlement; the host determines snippet window size.

## Build and limitations

Run iOS 27 CI (manual dispatch on this experiment branch) for Apple SDK compile validation. A successful build cannot validate host behavior: that needs an iPad Shortcuts run.

No existing share/quick-look code or signing configuration is modified. The demo loads bundled HTML, not a remote script, by default.

References:
- https://developer.apple.com/documentation/appintents/snippetintent
- https://developer.apple.com/documentation/appintents/displaying-static-and-interactive-snippets
- https://developer.apple.com/documentation/webkit/webkit-for-swiftui
- https://developer.apple.com/documentation/webkit/webpage/load(html:baseURL:)
