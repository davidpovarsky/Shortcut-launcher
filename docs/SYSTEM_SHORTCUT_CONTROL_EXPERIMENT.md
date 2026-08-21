# SystemShortcut in Control Center — experiment

This branch tests whether the public iOS/iPadOS 27 `SystemShortcut` / `RunSystemShortcutIntent` APIs can be used from a WidgetKit Control Center control even though Apple documents them for normal widget buttons.

## Results so far

The first attempt failed during `ExtractAppIntentsMetadata` because `SystemShortcut` may only appear on an intent conforming to `WidgetConfigurationIntent`. Dual conformance with `ControlConfigurationIntent` passed metadata extraction, built successfully, and Control Center displayed Apple's native System Shortcut picker.

On a real iPad, pressing the System Shortcut controls changed the action label to the hourglass briefly but did not run the chosen shortcut. This revision adds durable instrumentation before drawing a conclusion because the original notification-based control was also reported not to execute correctly.

## System Shortcut probes

- **LAB: Dual Config Shortcut** — one intent conforms to both `WidgetConfigurationIntent` and `ControlConfigurationIntent`, then calls `RunSystemShortcutIntent.perform()`.
- **LAB: Wrapped Shortcut** — a `WidgetConfigurationIntent` wrapper calls `RunSystemShortcutIntent.perform()`.
- **LAB: Main Target Shortcut** — same wrapper but forced to `.main` execution target.
- **LAB: Direct Shortcut** — passes `RunSystemShortcutIntent` directly to `ControlWidgetButton`.

The first three now log entry, the call immediately before `RunSystemShortcutIntent.perform()`, successful return, and thrown errors.

## Baseline Control Center probes

These isolate ordinary App Intent execution from the System Shortcut experiment:

- **LAB: Widget Ping** — plain AppIntent forced to `.widgetKitExtension`; only writes diagnostics.
- **LAB: Main Ping** — plain AppIntent forced to `.main`; only writes diagnostics.
- **LAB: Widget Notification** — fixed local notification forced to `.widgetKitExtension`; no launcher profile or App Entity involved.
- **LAB: Main Notification** — fixed local notification forced to `.main`; no launcher profile or App Entity involved.

The existing **Dav Launcher** control is deliberately kept on its original `.main` target and now has detailed logs throughout value resolution, profile lookup, state mutation, notification authorization, and notification submission. This makes the comparison meaningful rather than silently changing the production path while debugging it.

## App Group diagnostic

The app and WidgetKit extension depend on the App Group configured by `APP_GROUP_ID`. Re-signing or sideloading may remove or invalidate an App Group entitlement. If that happens, app and extension fall back to separate standard `UserDefaults` stores and configured profile UUIDs can diverge.

The Settings screen now reports whether the App Group container is actually available at runtime. A missing container is a major diagnostic result, not merely a cosmetic warning.

## Files-accessible log

Every important event is written to an App Group diagnostic log when the shared container exists. Whenever the main app launches/becomes active, it mirrors that log into the app Documents folder.

The app enables iOS file sharing/open-in-place so the mirrored log is visible in Files at:

```text
On My iPad > Dav Launcher > DavLauncher Logs > DavLauncher-Diagnostics.log
```

After testing Control Center, reopen Dav Launcher or go to Settings and tap **Sync Log to Files** before collecting the file.

## Recommended device test order

1. Open Dav Launcher > Settings and note **App Group Container: Available/MISSING**.
2. Clear the diagnostic log.
3. Press **LAB: Main Ping**.
4. Press **LAB: Widget Ping**.
5. Press **LAB: Main Notification**.
6. Press **LAB: Widget Notification**.
7. Press the existing configured **Dav Launcher** control.
8. Press **LAB: Dual Config Shortcut**, **Wrapped**, **Main Target**, and **Direct** with the same selected shortcut.
9. Reopen Dav Launcher, tap **Sync Log to Files**, then inspect/share `DavLauncher-Diagnostics.log`.

This sequence tells us independently whether Control Center executes ordinary App Intents, whether `.main` and `.widgetKitExtension` routing work, whether local notifications can be scheduled from each process, whether launcher profile resolution succeeds, and finally whether `RunSystemShortcutIntent` is the only remaining no-op.
