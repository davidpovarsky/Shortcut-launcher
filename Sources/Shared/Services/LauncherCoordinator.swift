import Foundation

enum LauncherCoordinator {
    @discardableResult
    static func activate(profileID: UUID) async throws -> LauncherProfile {
        DiagnosticLog.record("coordinator.activate.begin", details: ["profileID": profileID.uuidString])
        let updated: LauncherProfile
        do {
            updated = try SharedLauncherStore.updateProfile(id: profileID) { profile in
                profile.setState(.active)
            }
        } catch {
            DiagnosticLog.record("coordinator.activate.profileUpdateFailed", details: ["profileID": profileID.uuidString, "error": error.localizedDescription])
            throw error
        }
        DiagnosticLog.record("coordinator.activate.stateActive", details: ["profileID": profileID.uuidString, "profileName": updated.name])
        LauncherReloadService.reloadAll()

        do {
            try await NotificationService.send(profile: updated)
            DiagnosticLog.record("coordinator.activate.success", details: ["profileID": profileID.uuidString])
            return updated
        } catch {
            DiagnosticLog.record("coordinator.activate.notificationFailed", details: ["profileID": profileID.uuidString, "error": error.localizedDescription])
            _ = try? SharedLauncherStore.updateProfile(id: profileID) { profile in
                profile.setState(.failure)
            }
            LauncherReloadService.reloadAll()
            throw error
        }
    }

    @discardableResult
    static func setState(profileID: UUID, state: LauncherState) throws -> LauncherProfile {
        DiagnosticLog.record("coordinator.setState.begin", details: ["profileID": profileID.uuidString, "state": state.rawValue])
        let updated = try SharedLauncherStore.updateProfile(id: profileID) { profile in
            profile.setState(state)
        }
        LauncherReloadService.reloadAll()
        DiagnosticLog.record("coordinator.setState.success", details: ["profileID": profileID.uuidString, "state": state.rawValue])
        return updated
    }

    @discardableResult
    static func toggle(profileID: UUID) throws -> LauncherProfile {
        DiagnosticLog.record("coordinator.toggle.begin", details: ["profileID": profileID.uuidString])
        let updated = try SharedLauncherStore.updateProfile(id: profileID) { profile in
            let next: LauncherState = profile.resolvedState() == .active ? .idle : .active
            profile.setState(next)
        }
        LauncherReloadService.reloadAll()
        DiagnosticLog.record("coordinator.toggle.success", details: ["profileID": profileID.uuidString, "state": updated.state.rawValue])
        return updated
    }

    static func sendNotification(profileID: UUID, markActive: Bool, requestAuthorizationIfNeeded: Bool = false) async throws {
        DiagnosticLog.record("coordinator.sendNotification.begin", details: ["profileID": profileID.uuidString, "markActive": String(markActive)])
        let profile: LauncherProfile
        if markActive {
            profile = try SharedLauncherStore.updateProfile(id: profileID) { item in
                item.setState(.active)
            }
            LauncherReloadService.reloadAll()
        } else {
            guard let existing = SharedLauncherStore.profile(id: profileID) else {
                DiagnosticLog.record("coordinator.sendNotification.profileMissing", details: ["profileID": profileID.uuidString])
                throw LauncherError.profileNotFound
            }
            profile = existing
        }

        do {
            try await NotificationService.send(profile: profile, requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
            DiagnosticLog.record("coordinator.sendNotification.success", details: ["profileID": profileID.uuidString])
        } catch {
            DiagnosticLog.record("coordinator.sendNotification.error", details: ["profileID": profileID.uuidString, "error": error.localizedDescription])
            if markActive {
                _ = try? SharedLauncherStore.updateProfile(id: profileID) { item in
                    item.setState(.failure)
                }
                LauncherReloadService.reloadAll()
            }
            throw error
        }
    }
}
