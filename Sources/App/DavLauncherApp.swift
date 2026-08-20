import SwiftUI

@main
struct DavLauncherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = LauncherLibraryModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
