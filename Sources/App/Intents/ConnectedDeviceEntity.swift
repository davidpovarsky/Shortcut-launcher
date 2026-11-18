import AppIntents
import Foundation

/// One observation made during a single Shortcuts invocation.
/// Unknown values remain nil: never infer a Bluetooth battery percentage.
struct ConnectedDeviceRecord: Codable, Equatable, Sendable {
    var name: String
    var kind: String
    var source: String
    var connection: String = "Connected"
    var batteryLevels: [Int] = []
    var batteryState: String?
    var manufacturer: String?
    var model: String?
    var serialNumber: String?
    var firmwareVersion: String?
    var hardwareVersion: String?
    var bluetoothIdentifier: String?
    var audioPortUID: String?
    var audioPortType: String?
    var signalStrengthDBm: Int?
    var services: [String] = []
    var accessoryProtocols: [String] = []
    var capturedAt: Date = .now

    /// A device with multiple battery services may represent several cells.
    /// Do not arbitrarily label one cell's reading as the whole device battery.
    var batteryPercentage: Int? {
        batteryLevels.count == 1 ? batteryLevels[0] : nil
    }

    var batteryDescription: String {
        batteryLevels.isEmpty ? String(localized: "Not available") : batteryLevels.map { "\($0)%" }.joined(separator: ", ")
    }
}

enum ConnectedDeviceValueDecoder {
    static func batteryLevel(_ data: Data?) -> Int? {
        guard let data, data.count == 1, let value = data.first, value <= 100 else { return nil }
        return Int(value)
    }

    static func deviceText(_ data: Data?) -> String? {
        guard let data, let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return trimmed.isEmpty ? nil : String(trimmed.prefix(200))
    }
}

/// A real AppEntity, so Choose from List and Get Details work after this action.
/// Identifiers are per-scan snapshots and are NOT permanent hardware identifiers.
struct ConnectedDeviceEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Connected Device")
    static let defaultQuery = ConnectedDeviceEntityQuery()

    let id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Device Type")
    var kind: String

    @Property(title: "Connection")
    var connection: String

    @Property(title: "Information Source")
    var source: String

    @Property(title: "Battery Percentage")
    var batteryPercentage: Int?

    @Property(title: "Battery Readings")
    var batteryReadings: String

    @Property(title: "Battery State")
    var batteryState: String?

    @Property(title: "Manufacturer")
    var manufacturer: String?

    @Property(title: "Model")
    var model: String?

    @Property(title: "Serial Number")
    var serialNumber: String?

    @Property(title: "Firmware Version")
    var firmwareVersion: String?

    @Property(title: "Hardware Version")
    var hardwareVersion: String?

    @Property(title: "Bluetooth Identifier")
    var bluetoothIdentifier: String?

    @Property(title: "Audio Port Identifier")
    var audioPortUID: String?

    @Property(title: "Audio Port Type")
    var audioPortType: String?

    @Property(title: "Signal Strength (dBm)")
    var signalStrengthDBm: Int?

    @Property(title: "BLE Services")
    var services: String

    @Property(title: "Accessory Protocols")
    var accessoryProtocols: String

    @Property(title: "Observed At")
    var capturedAt: Date

    init(id: String, record: ConnectedDeviceRecord) {
        self.id = id
        name = record.name
        kind = record.kind
        connection = record.connection
        source = record.source
        batteryPercentage = record.batteryPercentage
        batteryReadings = record.batteryDescription
        batteryState = record.batteryState
        manufacturer = record.manufacturer
        model = record.model
        serialNumber = record.serialNumber
        firmwareVersion = record.firmwareVersion
        hardwareVersion = record.hardwareVersion
        bluetoothIdentifier = record.bluetoothIdentifier
        audioPortUID = record.audioPortUID
        audioPortType = record.audioPortType
        signalStrengthDBm = record.signalStrengthDBm
        services = record.services.joined(separator: ", ")
        accessoryProtocols = record.accessoryProtocols.joined(separator: ", ")
        capturedAt = record.capturedAt
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(kind) · Battery: \(batteryReadings)"
        )
    }
}

struct ConnectedDeviceEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ConnectedDeviceEntity] {
        ConnectedDeviceSnapshotStore.resolve(identifiers)
    }

    // Snapshots must only be returned by the live action; never present cached
    // items as a suggested list of devices still connected right now.
    func suggestedEntities() async throws -> [ConnectedDeviceEntity] { [] }
}

/// Retain results briefly to allow Shortcuts to resolve AppEntities in subsequent
/// actions. Cached records explicitly carry their observation time.
enum ConnectedDeviceSnapshotStore {
    private static let prefix = "connectedDevices.snapshot."
    private static let lifetime: TimeInterval = 10 * 60

    private struct Snapshot: Codable {
        let createdAt: Date
        let records: [ConnectedDeviceRecord]
    }

    static func save(_ records: [ConnectedDeviceRecord], session: String) throws {
        let defaults = AppEnvironment.sharedDefaults
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            guard let stored = value as? Data,
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: stored),
                  Date().timeIntervalSince(snapshot.createdAt) <= lifetime else {
                defaults.removeObject(forKey: key)
                continue
            }
        }
        defaults.set(try JSONEncoder().encode(Snapshot(createdAt: .now, records: records)), forKey: prefix + session)
    }

    static func resolve(_ identifiers: [String]) -> [ConnectedDeviceEntity] {
        let defaults = AppEnvironment.sharedDefaults
        var sessions: [String: [ConnectedDeviceRecord]] = [:]
        return identifiers.compactMap { identifier in
            let pieces = identifier.split(separator: ":", maxSplits: 1).map(String.init)
            guard pieces.count == 2,
                  let index = Int(pieces[1]), index >= 0 else { return nil }
            let session = pieces[0]
            if sessions[session] == nil {
                guard let stored = defaults.data(forKey: prefix + session),
                      let snapshot = try? JSONDecoder().decode(Snapshot.self, from: stored),
                      Date().timeIntervalSince(snapshot.createdAt) <= lifetime else { return nil }
                sessions[session] = snapshot.records
            }
            guard let records = sessions[session], records.indices.contains(index) else { return nil }
            return ConnectedDeviceEntity(id: identifier, record: records[index])
        }
    }
}
