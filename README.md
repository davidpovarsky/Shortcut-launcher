# Dav Launcher

Dav Launcher is an iOS/iPadOS 27 SwiftUI automation hub built around three system integrations:

1. Configurable Control Center controls that send a local notification and immediately switch to a persistent visual state.
2. App Intents that Shortcuts can call to set, reset, toggle, read, or notify a launcher profile.
3. An iOS/iPadOS 27 interactive widget that uses `RunSystemShortcutIntent` to directly open an installed app or run an App Shortcut, custom Shortcut, or system action.

The project is intentionally organized for GitHub Actions and XcodeGen so the repository stays readable and the Xcode project is regenerated deterministically.

## Important platform requirement

The direct launcher widget uses the beta iOS/iPadOS 27 `SystemShortcut` and `RunSystemShortcutIntent` APIs. Build with Xcode 27 and an iOS/iPadOS 27 SDK.

GitHub currently exposes an `xcode-27` runner image as a public preview. The included workflows use that runner.

## Repository layout

```text
DavLauncher/
├── .github/workflows/
│   ├── ci.yml
│   └── package-ipa.yml
├── Assets.xcassets/
├── Config/
│   ├── App-Info.plist
│   ├── DavLauncher.entitlements
│   ├── DavLauncherWidgets.entitlements
│   ├── ExportOptions.example.plist
│   └── Widgets-Info.plist
├── Resources/Localization/
│   ├── en.lproj/
│   └── he.lproj/
├── Sources/
│   ├── App/
│   ├── Shared/
│   │   ├── Configuration/
│   │   ├── Intents/
│   │   ├── Models/
│   │   ├── Presentation/
│   │   ├── Services/
│   │   └── Storage/
│   └── Widgets/
│       ├── Controls/
│       └── Widgets/
├── Tests/DavLauncherTests/
├── docs/
├── scripts/
├── Makefile
└── project.yml
```

## Core behavior

### Control Center

Each Control Center instance is configured with a `LauncherEntity`. Its value provider reads the current profile state from the shared App Group. The control changes icon, tint, and label from the profile's visual state.

Pressing the control runs `ActivateLauncherIntent`:

```text
Control press
  -> persist Active state
  -> request Control Center / widget reload
  -> send local notification
  -> Shortcuts Notification Automation runs
  -> Shortcut does its work
  -> Shortcut calls Set Launcher State / Reset Launcher
  -> Control returns to Idle or changes to Success/Error
```

The visual state is deliberately persistent: it stays Active, Success, or Error until the app or a Dav Launcher App Intent explicitly changes it. This makes a Shortcut callback the reliable source of truth instead of depending on extension timers.

### Direct iOS/iPadOS 27 widget

The Home Screen widget exposes a `SystemShortcut` parameter. In Edit Widget, iOS/iPadOS provides its system picker. The selected action may be an installed app, App Shortcut, custom Shortcut, or system action.

The widget button is implemented with:

```swift
Button(intent: RunSystemShortcutIntent(shortcut: configuration.shortcut))
```

Apple currently documents this system intent as widget-button-only. It is therefore not used by the Control Center control.

### App Intents exposed to Shortcuts

- Set Launcher State
- Reset Launcher
- Toggle Launcher State
- Send Launcher Notification
- Get Launcher State

`ActivateLauncherIntent` is internal to the Control Center control and intentionally not discoverable in Shortcuts.

## First GitHub build

1. Create an empty GitHub repository.
2. Upload the contents of this directory to the repository root.
3. Open the Actions tab.
4. Run **iOS 27 CI**, or push any commit.
5. The workflow will:
   - install XcodeGen if needed;
   - generate `DavLauncher.xcodeproj`;
   - print SDK, Xcode, Swift, simulator and runtime diagnostics;
   - compile the app and WidgetKit extension for an iPad simulator;
   - run unit tests;
   - boot an iPad simulator, install and launch the app;
   - capture a simulator screenshot and app logs;
   - compile a generic iOS device build without code signing;
   - verify that every embedded extension bundle ID has the required parent prefix;
   - package the unsigned device app as `DavLauncher-unsigned.ipa`;
   - upload the IPA, simulator app, screenshot and logs as a workflow artifact.

## Unsigned IPA versus installable IPA

The default CI intentionally builds with code signing disabled. This makes the workflow reproducible without putting Apple certificates or provisioning profiles in the repository.

`DavLauncher-unsigned.ipa` is a normal IPA container containing the unsigned app and extension, but it must be signed or re-signed before installation on a physical device. Tools such as your normal sideload/signing workflow can do that.

The bundle IDs are designed to avoid the common extension-prefix installation failure:

```text
Parent:    com.dav.DavLauncher
Extension: com.dav.DavLauncher.Widgets
```

The CI script `scripts/verify_bundle_ids.sh` fails the build if an embedded extension does not begin with the parent bundle ID.

If you use your own bundle identifier, run the manual **Package unsigned IPA** workflow and provide both values, for example:

```text
APP_BUNDLE_ID = com.example.MyLauncher
APP_GROUP_ID  = group.com.example.MyLauncher
```

When signing, make sure the App ID and Widget App ID have the same App Group capability enabled.

## Local Xcode 27 setup

On a Mac with Xcode 27:

```bash
brew install xcodegen
./scripts/bootstrap.sh
open DavLauncher.xcodeproj
```

Useful commands:

```bash
make diagnostics
make simulator
make test
make run
make ipa
```

## Notification Automation setup

1. Open Dav Launcher and allow notifications.
2. Create or edit a launcher profile.
3. Give it a stable token such as `DAV:READING`.
4. In Shortcuts, create a Notification Automation for Dav Launcher.
5. Filter the incoming notification by the token.
6. Run your desired Shortcut actions.
7. At the end, add Dav Launcher's `Reset Launcher` or `Set Launcher State` action.

See `docs/SHORTCUTS_SETUP.md` for the detailed flow.

## App Group

The app and WidgetKit extension share profiles through an App Group `UserDefaults` suite. The App Group identifier is injected into both Info.plists and both entitlement files through the `APP_GROUP_ID` build setting.

Default:

```text
group.com.dav.DavLauncher
```

For a signed build, create/enable that App Group in your Apple Developer account, or replace it with your own App Group.

## Current Apple API references

- WidgetKit controls: https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system
- AppIntentControlConfiguration: https://developer.apple.com/documentation/widgetkit/appintentcontrolconfiguration
- ControlCenter reload API: https://developer.apple.com/documentation/widgetkit/controlcenter
- RunSystemShortcutIntent: https://developer.apple.com/documentation/appintents/runsystemshortcutintent
- SystemShortcut: https://developer.apple.com/documentation/appintents/systemshortcut
- UserNotifications local notifications: https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app
- App Groups: https://developer.apple.com/documentation/xcode/configuring-app-groups

## Beta API note

`RunSystemShortcutIntent` and `SystemShortcut` are documented as beta APIs in the iOS/iPadOS 27 SDK. If Apple changes a signature in a later Xcode 27 beta, the CI logs intentionally preserve the full compiler diagnostic so the affected file is easy to update.
