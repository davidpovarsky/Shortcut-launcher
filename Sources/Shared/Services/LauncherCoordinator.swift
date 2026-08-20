import Foundation

enum LauncherCoordinator {
    @discardableResult
    static func activate(profileID: UUID) async throws -> LauncherProfile {
        let updated = try SharedLauncherStore.updateProfile(id: profileID) { profile in
            profile.setState(.active)
        }
        LauncherReloadService.reloadAll()

        do {
            try await NotificationService.send(profile: updated)
            return updated
        } catch {
            _ = try? SharedLauncherStore.updateProfile(id: profileID) { profile in
                profile.setState(.failure)
            }
            LauncherReloadService.reloadAll()
            throw error
        }
    }

    @discardableResult
    static func setState(
        profileID: UUID,
        state: LauncherState
    ) throws -> LauncherProfile {
        let updated = try SharedLauncherStore.updateProfile(id: profileID) { profile in
            profile.setState(state)
        }
        LauncherReloadService.reloadAll()
        return updated
    }

    @discardableResult
    static func toggle(profileID: UUID) throws -> LauncherProfile {
        let updated = try SharedLauncherStore.updateProfile(id: profileID) { profile in
            let next: LauncherState = profile.resolvedState() == .active ? .idle : .active
            profile.setState(next)
        }
        LauncherReloadService.reloadAll()
        return updated
    }

    static func sendNotification(
        profileID: UUID,
        markActive: Bool,
        requestAuthorizationIfNeeded: Bool = false
    ) async throws {
        let profile: LauncherProfile
        if markActive {
            profile = try SharedLauncherStore.updateProfile(id: profileID) { item in
                item.setState(.active)
            }
            LauncherReloadService.reloadAll()
        } else {
            guard let existing = SharedLauncherStore.profile(id: profileID) else {
                throw LauncherError.profileNotFound
            }
            profile = existing
        }

        do {
            try await NotificationService.send(
                profile: profile,
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
            )
        } catch {
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
