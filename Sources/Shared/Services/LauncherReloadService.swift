import WidgetKit

enum LauncherReloadService {
    static let controlKind = "com.dav.DavLauncher.Control"
    static let directWidgetKind = "com.dav.DavLauncher.DirectWidget"

    static func reloadAll() {
        ControlCenter.shared.reloadControls(ofKind: controlKind)
        WidgetCenter.shared.reloadTimelines(ofKind: directWidgetKind)
    }
}
