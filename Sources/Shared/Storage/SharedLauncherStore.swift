import Foundation

enum SharedLauncherStore {
    private static let profilesKey = "davlauncher.profiles.v2"

    static func loadProfiles(seedIfEmpty: Bool = true) -> [LauncherProfile] {
        let defaults = AppEnvironment.sharedDefaults

        guard let data = defaults.data(forKey: profilesKey),
              let profiles = try? JSONDecoder().decode([LauncherProfile].self, from: data) else {
            if seedIfEmpty {
                let samples = [LauncherProfile.sampleReading(), LauncherProfile.sampleLights()]
                DiagnosticLog.record(
                    "store.seedSamples",
                    details: [
                        "sharedContainerAvailable": String(AppEnvironment.sharedContainerURL != nil),
                        "ids": samples.map { $0.id.uuidString }.joined(separator: ",")
                    ]
                )
                try? saveProfiles(samples)
                return samples
            }
            return []
        }

        return profiles
    }

    static func saveProfiles(_ profiles: [LauncherProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        let defaults = AppEnvironment.sharedDefaults
        defaults.set(data, forKey: profilesKey)
        DiagnosticLog.record(
            "store.saveProfiles",
            details: [
                "count": String(profiles.count),
                "sharedContainerAvailable": String(AppEnvironment.sharedContainerURL != nil)
            ]
        )
    }

    static func profile(id: UUID) -> LauncherProfile? {
        loadProfiles(seedIfEmpty: false).first(where: { $0.id == id })
    }

    @discardableResult
    static func updateProfile(
        id: UUID,
        mutation: (inout LauncherProfile) -> Void
    ) throws -> LauncherProfile {
        var profiles = loadProfiles(seedIfEmpty: false)
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            DiagnosticLog.record(
                "store.updateProfile.notFound",
                details: [
                    "requestedID": id.uuidString,
                    "availableIDs": profiles.map { $0.id.uuidString }.joined(separator: ","),
                    "sharedContainerAvailable": String(AppEnvironment.sharedContainerURL != nil)
                ]
            )
            throw LauncherError.profileNotFound
        }
        mutation(&profiles[index])
        profiles[index].updatedAt = .now
        try saveProfiles(profiles)
        return profiles[index]
    }

    static func replace(_ profile: LauncherProfile) throws {
        var profiles = loadProfiles(seedIfEmpty: false)
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        try saveProfiles(profiles)
    }

    static func delete(id: UUID) throws {
        var profiles = loadProfiles(seedIfEmpty: false)
        profiles.removeAll(where: { $0.id == id })
        try saveProfiles(profiles)
    }
}
