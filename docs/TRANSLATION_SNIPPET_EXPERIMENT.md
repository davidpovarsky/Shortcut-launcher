# Apple Translate Popover from a Shortcuts Snippet (experimental)

Branch: experiment/shortcuts-share-extension-invocation
Minimum OS: iPadOS 27 (current project deployment target).

## Objective

Test the *native* SwiftUI Apple Translate sheet/popover from an actual
Shortcuts-hosted \`SnippetIntent\`. This is **not** a web translation API,
a fake HTML dialog, or a request to open the Translate app.

The SwiftUI API is \`.translationPresentation(isPresented:text:)\`.
Apple documents this modifier for ordinary app views, but does not guarantee
presentation from a system-hosted App Intents snippet.

## Action

\`LAB: Apple Translate Snippet\` (Shortcuts discoverable, no AppShortcut tile required).

Parameter: optional **Text to Translate**; a default English sample is provided.

Two independent controls render inside one native snippet:

1. **Open Translate · AppIntent** — documented interactive snippet path:
   \`Button(intent:)\` invokes \`RequestTranslationPopoverSnippetIntent\`,
   writes a one-shot pending flag, requests a snippet reload, and the next
   \`perform()\` returns a view which attempts to present Apple Translate
   in its \`.task\`.
2. **Open Translate · SwiftUI** — direct SwiftUI \`Button(action:)\` toggles
   \`@State\`, to check whether the host permits ordinary view actions.
   Apple does not promise such actions work inside snippets.

Both paths use the **same** native \`.translationPresentation\` modifier.
The AppIntent request flag is consumed once to prevent indefinite re-opening.

## iPad acceptance

1. Install this branch's new IPA and launch DavLauncher once.
2. In Shortcuts, add DavLauncher > **LAB: Apple Translate Snippet**.
3. Optionally supply text; run and confirm the snippet appears.
4. Tap **Open Translate · AppIntent**. If the status changes to
   "AppIntent request received", the interactive action and refresh path worked.
   Observe whether the official Apple Translate interface appears above the snippet.
5. Dismiss it, rerun the Shortcut and tap **Open Translate · SwiftUI**.
6. Note outcomes separately: button ignored / status changed without popover /
   actual system Translate UI / prohibited-content placeholder / app foregrounded.
7. If possible, compare to the exact modifier in a regular in-app view.
   That control distinguishes a host restriction from an invalid API call.

A successful Xcode build validates SDK syntax and packaging, **not**
Shortcuts-hosted modal behavior. This experiment does not alter other snippets,
Share Extensions, app entry points, translation default providers or signing.

References:
- https://developer.apple.com/documentation/appintents/snippetintent
- https://developer.apple.com/documentation/swiftui/view/translationpresentation(isPresented:text:attachmentAnchor:arrowEdge:replacementAction:)
