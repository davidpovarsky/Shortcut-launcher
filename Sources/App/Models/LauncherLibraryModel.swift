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
        DiagnosticLog.recordEnvironment("LauncherLibraryModel.init")
        refresh()
        selectedID = profiles.first?.id
    }

    var selectedProfile: LauncherProfile? {
        guard let selectedID else { return nil }
        return profiles.first(where: { $0.id == selectedID })
    }

    func refresh() {
        profiles = SharedLauncherStore.loadProfiles()
        DiagnosticLog.record(
            "library.refresh",
            details: [
                "count": String(profiles.count),
                "ids": profiles.map { $0.id.uuidString }.joined(separator: ",")
            ]
        )
        if let selectedID, !profiles.contains(where: { $0.id == selectedID }) {
            self.selectedID = profiles.first?.id
        }
    }

    func save(_ profile: LauncherProfile) {
        do {
            var copy = profile
            copy.updatedAt = .now
            try SharedLauncherStore.replace(copy)
            DiagnosticLog.record("library.save.success", details: ["profileID": copy.id.uuidString])
            refresh()
            selectedID = copy.id
            LauncherReloadService.reloadAll()
        } catch {
            DiagnosticLog.record("library.save.error", details: ["profileID": profile.id.uuidString, "error": error.localizedDescription])
            lastErrorMessage = error.localizedDescription
        }
    }

    func delete(_ profile: LauncherProfile) {
        do {
            try SharedLauncherStore.delete(id: profile.id)
            DiagnosticLog.record("library.delete.success", details: ["profileID": profile.id.uuidString])
            refresh()
            LauncherReloadService.reloadAll()
        } catch {
            DiagnosticLog.record("library.delete.error", details: ["profileID": profile.id.uuidString, "error": error.localizedDescription])
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
            DiagnosticLog.record("library.setState.error", details: ["profileID": profile.id.uuidString, "error": error.localizedDescription])
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await NotificationService.authorizationStatus()
        DiagnosticLog.record(
            "library.notificationAuthorizationStatus",
            details: ["status": String(notificationAuthorizationStatus.rawValue)]
        )
    }

    func requestNotificationAuthorizationIfNeeded() async {
        await refreshNotificationAuthorizationStatus()
        guard notificationAuthorizationStatus == .notDetermined else {
            DiagnosticLog.record("library.requestAuthorizationIfNeeded.skipped", details: ["status": String(notificationAuthorizationStatus.rawValue)])
            return
        }

        do {
            _ = try await NotificationService.requestAuthorization()
            await refreshNotificationAuthorizationStatus()
        } catch {
            DiagnosticLog.record("library.requestAuthorizationIfNeeded.error", details: ["error": error.localizedDescription])
            lastErrorMessage = error.localizedDescription
        }
    }

    func requestNotificationAuthorization() async {
        do {
            _ = try await NotificationService.requestAuthorization()
            await refreshNotificationAuthorizationStatus()
        } catch {
            DiagnosticLog.record("library.requestAuthorization.error", details: ["error": error.localizedDescription])
            lastErrorMessage = error.localizedDescription
        }
    }

    func sendTestNotification(for profile: LauncherProfile) async {
        DiagnosticLog.record("library.testNotification.begin", details: ["profileID": profile.id.uuidString])
        do {
            _ = try await NotificationService.ensureAuthorization(requestIfNeeded: true)
            try await LauncherCoordinator.sendNotification(
                profileID: profile.id,
                markActive: true,
                requestAuthorizationIfNeeded: false
            )
            await refreshNotificationAuthorizationStatus()
            refresh()
            DiagnosticLog.record("library.testNotification.success", details: ["profileID": profile.id.uuidString])
        } catch {
            await refreshNotificationAuthorizationStatus()
            DiagnosticLog.record("library.testNotification.error", details: ["profileID": profile.id.uuidString, "error": error.localizedDescription])
            lastErrorMessage = error.localizedDescription
        }
    }
}
