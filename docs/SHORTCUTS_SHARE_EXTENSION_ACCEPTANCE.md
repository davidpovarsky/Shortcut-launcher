# Shortcuts → Share Extension invocation experiment

Base: `experiment/spotlight-search-in-app` (commit `fdfc58e`).

## Existing extension targets (unchanged)
- DavLauncherShareCompact: `com.dav.DavLauncher.ShareCompact`, requested 420×220 pt
- DavLauncherShareMedium: `com.dav.DavLauncher.ShareMedium`, requested 540×460 pt
- DavLauncherShareExpanded: `com.dav.DavLauncher.ShareExpanded`, requested 720×760 pt

All three use `Sources/ShareExtension/ShareViewController.swift` and `Config/ShareLab-Info.plist`, with `NSExtensionPointIdentifier=com.apple.share-services`. The controller already records requested and actual bounds via DiagnosticLog.

## Device acceptance test (iPadOS 27)

1. Install a build from this branch, signed with all three Share Extension targets embedded.
2. Confirm that all three Dav entries appear when sharing a plain text item from a standard host app.
3. Create a Shortcut: **Text** (e.g. `DAV-SHORTCUTS-SHARE-TEST`) → **Share** (or **Share with Extensions**, if available on this iPadOS build).
4. Run the Shortcut inside the Shortcuts app. Select **Dav Expanded** from the system share sheet.
5. Verify that the Dav Expanded UI is shown while Shortcuts remains the host; record a screenshot and the **Requested / Actual** size displayed by the extension.
6. Repeat for **Dav Medium** and **Dav Compact**.
7. Try text, URL and image payloads; verify each type is received and that **Done** and **Cancel** return to the Shortcut correctly.
8. Repeat from the Shortcuts editor and from a Home Screen shortcut launch. Note any host differences.

## Result matrix

| Test | Expected | Actual | Pass? |
| --- | --- | --- | --- |
| Share action offers Dav Expanded | Extension listed | Not yet tested on device | Pending |
| Expanded UI appears without foregrounding Dav Launcher | Extension hosted by system | Not yet tested on device | Pending |
| Expanded requested 720×760 vs actual | Actual measured, may be clamped by system | Not yet tested | Pending |
| Medium 540×460 | Actual measured | Not yet tested | Pending |
| Compact 420×220 | Actual measured | Not yet tested | Pending |
| Text / URL / image input | Payload displayed and logged | Not yet tested | Pending |
| Done / Cancel | Extension dismisses | Not yet tested | Pending |
| Dedicated App Intent launches a specific Share Extension directly | **Not supported by any established public API in this repository** | Not implemented | Unsupported/unproven |

## API boundary

A Share Extension is instantiated by an extension host, not by arbitrary `AppIntent.perform()` code. Do not attempt to call the extension's `UIViewController` directly from an App Intent or use private URL schemes. A foreground App Intent could open the containing app and show `UIActivityViewController`, but that **does not** meet the requirement to stay within Shortcuts. The built-in Share action is the supported experiment here.

## Diagnostics to collect

- Screenshot of the Shortcuts action, the system share sheet and the displayed Dav UI
- Requested/Actual sizes from the view
- DiagnosticLog entries `shareLab.viewDidLoad`, `shareLab.layout`, `shareLab.input.received`, `shareLab.complete` or `shareLab.cancel`
- Whether the host remained Shortcuts

No test result is marked passed until confirmed on a real device.