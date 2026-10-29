# Dav AI Compose — Share Extension + Action Extension experiment

## Intent

A native **Apple system composer** plus a separate **Action entry** in the iPadOS Share Sheet, both capturing text and files into a local App Group inbox for a future AI agent. Existing Share Compact/Medium/Expanded and Action lab extensions are retained unchanged.

This is **not** a Shortcuts SnippetIntent, and using a Share extension does **not** itself return an output variable to the next Shortcuts action. Users open the iOS Share Sheet from an app that supports sharing.

## Two distinct system entries

1. **Dav AI Compose** — target \`DavLauncherAIComposeShare\`, \`com.apple.share-services\`.
   - Native \`SLComposeServiceViewController\` from Apple's Social framework.
   - Apple's editable compose text field and Post/Cancel buttons, plus attachment preview automatically supplied by the host system.
   - An **צירוף קבצים** configuration row opens Apple's Files document picker (\`UIDocumentPickerViewController\`) for *additional* attachments. The row shows the current attachment count.
   - On Post, store the draft in App Group and close the native composer. No AI model/network request is initiated.

2. **Dav AI Compose Action** — target \`DavLauncherAIComposeAction\`, \`com.apple.ui-services\`.
   - Separate Action extension entry in the Share Sheet (typically in the Actions list).
   - A custom but native UIKit form with editable text, incoming shared data, attachment picker and Save/Cancel buttons. \`SLComposeServiceViewController\` is intended for Share extensions, so we do **not** pretend it can render the same system composer inside an Action extension.
   - Stores the same manifest and attachment files in the same App Group inbox.

Both support text, URLs, images, movies and files via their \`NSExtensionActivationRule\`. iOS ultimately decides which entries are shown for a particular source app and shared content type.

## Storage format and integrity

App Group: \`AppEnvironment.appGroupID\` resolved for a SideStore re-signed install.

Files:
\`\`\`
<App Group>/AIComposeInbox/<UUID>/
    draft.json
    <UUID>.pdf
    <UUID>.png
    ...
\`\`\`

The draft JSON includes \`id\`, \`createdAt\`, \`message\` (text typed into compose view), \`source\` (system share or Action), \`sharedText\` (text/URLs received from the host), and \`attachments\` (name, byte size, UTType, stored relative filename and source).

- A provider's temporary file is copied **inside** \`NSItemProvider.loadFileRepresentation\`'s completion handler, before the host deletes it.
- Files selected via the document picker are copied into the same App Group folder, using security-scoped access where available.
- Each attachment is limited to 80 MiB, and a draft is limited to 20 attachments. Oversized or unreadable items are reported as errors; stored attachment count is visible in the Action UI.
- Only publish the latest-draft pointer **after** writing the JSON manifest.
- Cancellation removes temporary unsent session files. Previously saved drafts remain locally until cleaned up by the app.
- No sensitive user content is written into the global DiagnosticLog: only IDs and item counts.

Main-app diagnostic App Intent: **LAB: Last AI Compose Draft**. It returns the latest JSON manifest as a String to a Shortcut for inspection; the *actual attachments remain on disk in the App Group*, accessible to app-side agent logic via \`AIComposeDraftStore.fileURL(for:in:)\`.

## Test on iPad

1. Install the latest SideStore re-signed IPA.
2. Open Files or Photos, select an image/PDF, tap **Share**.
3. In the app destinations, look for **Dav AI Compose**. If hidden, use More/Edit to enable it. Open it; type a message, optionally choose **צירוף קבצים** to add another file, then Post. Verify the stock Apple text field and attachment preview. The additional file may be listed via the configuration count rather than included in the stock preview.
4. Open the Share Sheet again and scroll the actions section. Look for **Dav AI Compose Action**. Open; type text, select a file via **צרף קבצים**, then **שמור לסוכן**.
5. In Shortcuts add **LAB: Last AI Compose Draft**, followed by **Show Result** using the previous action's magic variable. Verify the saved JSON has your text, source and attachment names.
6. Test canceling each entry: an unsent session should not replace the latest saved draft.
7. If the new entries fail to appear, verify the new targets' \`Info.plist\` activation rules and that the IPA contains both new \`.appex\` bundles with the appropriate \`NSExtensionPointIdentifier\`.

## Important scope limits

- The Share extension is a standard Apple composer but **does not give an unrestricted custom text+attachment toolbar**. New files are added via a configuration row that launches a document picker.
- A Share Sheet extension cannot normally be launched simply by performing an App Intent nor return its result as the normal output of the same running Shortcut. The diagnostic App Intent reads a previously saved draft separately.
- **No AI request is submitted.** This captures and stores the data locally so a later agent integration can consume it. The UI button says "שמור לסוכן" (save for agent), not "Send to AI".
- Opening the Share Sheet as a modal panel is controlled by iPadOS, not by the extension's requested preferred size.

## Build packaging

Targets are embedded in the host app via \`project.yml\`; the fast IPA workflow still builds for generic iOS without simulator tests. \`scripts/build_unsigned_ipa.sh\` verifies both new \`.appex\` paths, checks their extension point identifiers and ad-hoc signs their App Group entitlements in addition to WidgetKit and the host app, before creating \`DavLauncher-SideStore.ipa\`.

Apple documentation:
- https://developer.apple.com/documentation/social/slcomposeserviceviewcontroller
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html
- https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)
