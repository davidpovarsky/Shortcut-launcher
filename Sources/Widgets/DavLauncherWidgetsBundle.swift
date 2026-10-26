import SwiftUI
import WidgetKit
import ActivityKit

@main
struct DavLauncherWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WebLabLiveWidget()
        LauncherControl()

        DiagnosticWidgetPingControl()
        DiagnosticMainPingControl()
        DiagnosticWidgetNotificationControl()
        DiagnosticMainNotificationControl()

        ExperimentalDualConfigurationShortcutControl()
        ExperimentalWrappedSystemShortcutControl()
        ExperimentalMainTargetSystemShortcutControl()
        ExperimentalDirectSystemShortcutControl()

        DirectLauncherWidget()
    }
}

struct WebLabLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WebLabActivityAttributes.self) { context in
            Text("Dav Web Lab: \(context.state.status)")
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Dav Web Lab")
                }
            } compactLeading: {
                Text("WEB")
            } compactTrailing: {
                Text("120s")
            } minimal: {
                Text("W")
            }
        }
    }
}
