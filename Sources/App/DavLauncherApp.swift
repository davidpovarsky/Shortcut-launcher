import CoreSpotlight
import SwiftUI

@main
struct DavLauncherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var library = LauncherLibraryModel()
    @State private var webLabStarting = false
    @StateObject private var spotlightSearchCoordinator = SpotlightSearchCoordinator.shared
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    @MainActor
    private func consumeWebLabStartRequest() async {
        guard !webLabStarting, WebLabStartRequest.take() else { return }
        webLabStarting = true
        defer { webLabStarting = false }
        do {
            let response = try await WebLabServer.ensureHealthy()
            WebLabLog.write("Foreground app started listener: \(response)")
        } catch {
            WebLabLog.write("Foreground app listener start failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await consumeWebLabStartRequest() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await consumeWebLabStartRequest() }
                    } else {
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
