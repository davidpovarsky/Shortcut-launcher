import SwiftUI

@main
struct DavLauncherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = LauncherLibraryModel()
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(\.locale, language.locale)
                .environment(\.layoutDirection, language.layoutDirection)
        }
    }
}
