import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class LauncherLibraryModel {
    var profiles: [LauncherProfile] = []
    var selectedID: UUID?
    var lastErrorMessage: String?
    var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        refresh()
        selectedID = profiles.first?.id
    }

    var selectedProfile: LauncherProfile? {
        guard let selectedID else { return nil }
        return profiles.first(where: { $0.id == selectedID })
    }

    func refresh() {
        profiles = SharedLauncherStore.loadProfiles()
        if let selectedID, !profiles.contains(where: { $0.id == selectedID }) {
            self.selectedID = profiles.first?.id
        }
    }

    func save(_ profile: LauncherProfile) {
        do {
            var copy = profile
            copy.updatedAt = .now
            try SharedLauncherStore.replace(copy)
            refresh()
            selectedID = copy.id
            LauncherReloadService.reloadAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func delete(_ profile: LauncherProfile) {
        do {
            try SharedLauncherStore.delete(id: profile.id)
            refresh()
            LauncherReloadService.reloadAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func duplicate(_ profile: LauncherProfile) {
        var copy = profile
        copy.id = UUID()
        copy.name += " Copy"
        copy.state = .idle
        copy.createdAt = .now
        copy.updatedAt = .now
        save(copy)
    }

    func setState(_ state: LauncherState, for profile: LauncherProfile) {
        do {
            _ = try LauncherCoordinator.setState(profileID: profile.id, state: state)
            refresh()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await NotificationService.authorizationStatus()
    }

    func requestNotificationAuthorizationIfNeeded() async {
        await refreshNotificationAuthorizationStatus()
        guard notificationAuthorizationStatus == .notDetermined else { return }

        do {
            _ = try await NotificationService.requestAuthorization()
            await refreshNotificationAuthorizationStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func requestNotificationAuthorization() async {
        do {
            _ = try await NotificationService.requestAuthorization()
            await refreshNotificationAuthorizationStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func sendTestNotification(for profile: LauncherProfile) async {
        do {
            _ = try await NotificationService.ensureAuthorization(requestIfNeeded: true)
            try await LauncherCoordinator.sendNotification(
                profileID: profile.id,
                markActive: true,
                requestAuthorizationIfNeeded: false
            )
            await refreshNotificationAuthorizationStatus()
            refresh()
        } catch {
            await refreshNotificationAuthorizationStatus()
            lastErrorMessage = error.localizedDescription
        }
    }
}
