import SwiftUI
import WidgetKit

@main
struct DavLauncherWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LauncherControl()
        DirectLauncherWidget()
    }
}
