# Architecture

## Targets

### DavLauncher

The SwiftUI application. It owns profile management, notification permission UI, manual state controls, profile editing, and App Shortcut discovery.

### DavLauncherWidgets

A WidgetKit extension containing both:

- `LauncherControl`, the configurable Control Center control.
- `DirectLauncherWidget`, the interactive direct-launch widget using `RunSystemShortcutIntent`.

Apple supports exposing controls and widgets from the same WidgetBundle.

## Shared layer

Everything under `Sources/Shared` is compiled into both the app and the WidgetKit extension. Shared code never imports UIKit or uses application-only APIs.

### Models

`LauncherProfile` is the root persistent object. It owns:

- name and stable UUID;
- idle / active / success / failure appearance;
- local notification payload and automation token;
- current state;
- creation and update timestamps.

### Storage

`SharedLauncherStore` encodes the profile array as JSON `Data` inside the App Group UserDefaults suite. This keeps reads inexpensive for WidgetKit value providers and AppEntity queries.

### Services

`LauncherCoordinator` is the single mutation entry point used by the UI and App Intents. Every mutation reloads the Control Center control and direct widget timeline.

### App Intents

`LauncherEntity` gives Shortcuts and WidgetKit a persistent entity picker backed by the shared store.

## Why state is explicitly persistent

A WidgetKit/App Intent process may be suspended immediately after `perform()` returns, so a delayed in-process timer is not a reliable way to reset a Control Center appearance. Dav Launcher therefore keeps the selected state until an explicit App Intent changes it. A Shortcut can set Success/Error and then call Reset Launcher whenever its workflow is actually complete.

## Control versus direct widget

Control Center cannot use `RunSystemShortcutIntent` directly because Apple documents the intent as effective only when triggered by a button inside a widget. The Control Center path uses a local notification and a Shortcuts Notification Automation.

The Home Screen direct widget has the opposite advantage: the system itself performs the selected app/shortcut/system action, so no notification bridge is needed.
