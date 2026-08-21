import SwiftUI
import WidgetKit

@main
struct DavLauncherWidgetsBundle: WidgetBundle {
    var body: some Widget {
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
