# Wikipedia Discovery — multi-step interactive Shortcut (iPadOS 27)

## What it does

Shortcuts action: **Dav Launcher → LAB: Wikipedia Discovery**

The user gets one **real random Hebrew Wikipedia article** at a time. The action loads article title, the plain-text introductory extract, canonical Wikipedia URL, and (where available) a small Wikimedia thumbnail through Wikipedia's public MediaWiki API. It then shows a **native interactive confirmation snippet**, with an editorial SwiftUI preview card:

- **חפש שוב**: deny/cancel confirmation. The parent intent deliberately catches the confirmation exception, fetches a genuinely new random Wikipedia page, and presents another preview **without returning to the Shortcut**.
- **פתח**: accept confirmation. Parent intent returns the selected article's `URL` to the **next Shortcut action**. It does not automatically launch Safari; the Shortcuts user chooses what to do with the returned URL.

This deliberately reuses behavior the user already verified on their own iPadOS 27 installation with the `LAB: Confirmation Back or Next` diagnostic. Apple documents snippet-driven confirmation sequences, but recommends not swallowing cancellation. Thus this cancel-to-retry loop is an **experimental and potentially version-specific technique**.

## Architecture

- `WikipediaRandomExplorerIntent` is the single discoverable parent AppIntent, with result `ReturnsValue<URL>`. It controls the repeat-fetch/prompt/return loop.
- A *different* `WikipediaArticleSnippetIntent` displays the rich card inside each native `requestConfirmation(actionName:dialog:showDialogAsPrompt:snippetIntent:)` request. The snippet isn't discoverable as a separate action.
- Article snapshots (including image data if downloaded) live in an App Group `UserDefaults` session. This allows a system-hosted snippet running in a separate process to load exactly the article the parent intent just fetched.
- The app uses MediaWiki `generator=random` with main-namespace filtering, extracts, pageimages, fullurl, an HTTP User-Agent, and fresh no-cache probe IDs.
- Empty stubs are skipped (up to eight fetches per article). An article without a thumbnail gets an elegant SF Symbol fallback. HTTP errors are surfaced rather than faked.
- The loop is bounded to 60 accepted/retried article previews per invocation to avoid uncontrolled requests if a system host changes its behavior.

API example:
`https://he.wikipedia.org/w/api.php?action=query&generator=random&grnnamespace=0&grnminsize=2000&grnlimit=1&prop=extracts%7Cpageimages%7Cinfo&inprop=url&exintro=1&explaintext=1&pithumbsize=320&format=json&formatversion=2`

### Test in Shortcuts

1. Install the latest signed build from the experiment branch.
2. Create Shortcut:
    - **Dav Launcher → LAB: Wikipedia Discovery**
    - **Show Result** set to the previous action's magic variable.
3. Run and press **חפש שוב** at least three times. Every tap should fetch a new article and replace the displayed card while **Show Result does not run**.
4. Press **פתח**. The confirmation should close; **Show Result** should display that article's `https://he.wikipedia.org/wiki/...` link.
5. Test again with weak network: do not show fake content; the API failure should be surfaced.
6. If only the text but not the thumbnail renders, the image may be unsupported by the snippet host; the no-image fallback must remain functional.

### Limits

- This is an App Intent's native confirmation snippet; no WebKit/ShareLink or custom overlay controls are required. The native confirmation buttons belong to iPadOS.
- The title and summary are real Wikipedia content, not AI-generated.
- The system decides the snippet size. Our content is compact enough for the panel.
- **חפש שוב** uses the documented cancel action but intentionally catches it. That is empirically working in the user's previous Back/Next lab but is not contractually guaranteed by Apple for future releases.

## Build optimization

Use the existing manual workflow **Package unsigned IPA**, now streamlined for rapid device iterations. It skips **all simulator build/install**, unit tests, redundant XcodeGen invocation, repeated notification refreshes and unconditional diagnostics. It does:
`checkout → build_unsigned_ipa.sh (XcodeGen + Release device build + verification + ad-hoc signing + IPA) → upload`.

Build script still includes required app and WidgetKit-extension verification/signing. It produces **DavLauncher-SideStore.ipa**, which is ad-hoc signed for entitlement preservation and **must still be provisioned/re-signed by SideStore**. This is not an Apple Developer distribution-signed IPA.

Previous successful runs showed approximately **2–2.5 minutes** for Package unsigned IPA, versus approximately **16–20 minutes** for full iOS 27 CI. The latter remains unchanged and should be used for occasional simulator tests and unit tests.

Do **not** eliminate the generic iOS device build, required embedded extensions or correct entitlements: the IPA needs all of them to work.

## Reference documentation

- Apple: https://developer.apple.com/documentation/appintents/displaying-static-and-interactive-snippets
- Apple: https://developer.apple.com/documentation/appintents/appintent/requestconfirmation(conditions:actionname:dialog:showdialogasprompt:snippetintent:)
- MediaWiki: https://www.mediawiki.org/wiki/API:Random
