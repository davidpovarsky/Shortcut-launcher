import CoreSpotlight
import SwiftUI

@main
struct DavLauncherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\\.scenePhase) private var scenePhase
    @State private var library = LauncherLibraryModel()
    @StateObject private var spotlightSearchCoordinator = SpotlightSearchCoordinator.shared
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        WebLabServer.shared.stop()
                    }
                }
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
