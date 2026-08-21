import AppIntents
import SwiftUI
import WidgetKit

/// Experiment A: the dual-purpose WidgetConfigurationIntent is also the
/// Control Center action. No SystemShortcut is copied into a plain AppIntent.
struct ExperimentalDualConfigurationShortcutControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.experimental.systemShortcut.dualConfiguration"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ExperimentalSystemShortcutConfigurationIntent.self
        ) { configuration in
            ControlWidgetButton(
                action: ExperimentalSystemShortcutConfigurationIntent(
                    shortcut: configuration.shortcut
                )
            ) {
                Label("Dual Config", systemImage: "rectangle.2.swap")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : "Dual Config",
                    systemImage: isPerforming ? "hourglass" : "rectangle.2.swap"
                )
            }
            .disabled(configuration.shortcut == nil)
        }
        .displayName("LAB: Dual Config Shortcut")
        .description(
            "Uses one intent as both WidgetConfigurationIntent and ControlConfigurationIntent, then runs it as the control action."
        )
        .promptsForUserConfiguration()
    }
}

/// Experiment B: a wrapper that is formally a WidgetConfigurationIntent calls
/// RunSystemShortcutIntent.perform() from its perform() implementation.
struct ExperimentalWrappedSystemShortcutControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.experimental.systemShortcut.wrappedWidgetIntent"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ExperimentalSystemShortcutConfigurationIntent.self
        ) { configuration in
            ControlWidgetButton(
                action: ExperimentalWrappedSystemShortcutIntent(
                    shortcut: configuration.shortcut
                )
            ) {
                Label("Wrapped", systemImage: "arrow.trianglehead.branch")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : "Wrapped",
                    systemImage: isPerforming ? "hourglass" : "arrow.trianglehead.branch"
                )
            }
            .disabled(configuration.shortcut == nil)
        }
        .displayName("LAB: Wrapped Shortcut")
        .description(
            "Runs a WidgetConfigurationIntent wrapper that invokes RunSystemShortcutIntent.perform()."
        )
        .promptsForUserConfiguration()
    }
}

/// Experiment C: same wrapper, but handed to the containing app's main
/// execution target before calling RunSystemShortcutIntent.perform().
struct ExperimentalMainTargetSystemShortcutControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.experimental.systemShortcut.mainTargetWidgetIntent"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ExperimentalSystemShortcutConfigurationIntent.self
        ) { configuration in
            ControlWidgetButton(
                action: ExperimentalMainTargetSystemShortcutIntent(
                    shortcut: configuration.shortcut
                )
            ) {
                Label("Main Target", systemImage: "app.badge")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : "Main Target",
                    systemImage: isPerforming ? "hourglass" : "app.badge"
                )
            }
            .disabled(configuration.shortcut == nil)
        }
        .displayName("LAB: Main Target Shortcut")
        .description(
            "Runs the wrapper on the main execution target before invoking RunSystemShortcutIntent.perform()."
        )
        .promptsForUserConfiguration()
    }
}

/// Experiment D: give RunSystemShortcutIntent directly to ControlWidgetButton.
///
/// The control configuration parameter must be optional for an unconfigured
/// control, while RunSystemShortcutIntent requires a concrete SystemShortcut.
/// `.promptsForUserConfiguration()` should configure the control before use;
/// this deliberate force unwrap lets the compiler/metadata/runtime test the
/// direct action path rather than hiding it behind another intent.
struct ExperimentalDirectSystemShortcutControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.experimental.systemShortcut.direct"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ExperimentalSystemShortcutConfigurationIntent.self
        ) { configuration in
            ControlWidgetButton(
                action: RunSystemShortcutIntent(
                    shortcut: configuration.shortcut!
                )
            ) {
                Label("Direct", systemImage: "bolt.fill")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : "Direct",
                    systemImage: isPerforming ? "hourglass" : "bolt.fill"
                )
            }
            .disabled(configuration.shortcut == nil)
        }
        .displayName("LAB: Direct Shortcut")
        .description(
            "Passes RunSystemShortcutIntent directly to ControlWidgetButton. Experimental: configure it immediately after adding."
        )
        .promptsForUserConfiguration()
    }
}
