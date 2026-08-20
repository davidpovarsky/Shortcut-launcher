import AppIntents
import Foundation

struct LauncherEntity: AppEntity, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Launcher")
    static let defaultQuery = LauncherEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(profile: LauncherProfile) {
        self.id = profile.id
        self.name = profile.name
    }
}

struct LauncherEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [LauncherEntity] {
        let ids = Set(identifiers)
        return SharedLauncherStore.loadProfiles(seedIfEmpty: false)
            .filter { ids.contains($0.id) }
            .map(LauncherEntity.init(profile:))
    }

    func suggestedEntities() async throws -> [LauncherEntity] {
        SharedLauncherStore.loadProfiles().map(LauncherEntity.init(profile:))
    }
}
