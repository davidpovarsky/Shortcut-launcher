import CoreSpotlight
import SwiftUI

@main
struct DavLauncherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = LauncherLibraryModel()
    @StateObject private var spotlightSearchCoordinator = SpotlightSearchCoordinator.shared
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
                .onContinueUserActivity(CSQueryContinuationActionType) { userActivity in
                    _ = spotlightSearchCoordinator.receive(
                        userActivity: userActivity,
                        source: .swiftUIScene
                    )
                }
                .sheet(
                    item: $spotlightSearchCoordinator.activeRequest,
                    onDismiss: {
                        spotlightSearchCoordinator.dismiss()
                    }
                ) { request in
                    SefariaSearchView(request: request)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
        }
    }
}
