import AppIntents
import Foundation

/// Runs on demand in Shortcuts. Returns actual typed device objects, not JSON.
struct GetConnectedDevicesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Connected Devices"
    static let description = IntentDescription(
        "List accessible connected audio, Bluetooth LE and external accessories. Reads battery levels only when the device exposes them to public iOS APIs; unavailable values are not estimated."
    )
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Get connected devices and available battery details")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<[ConnectedDeviceEntity]> {
        let records = await ConnectedDeviceCollector.collect()
        let session = UUID().uuidString
        try ConnectedDeviceSnapshotStore.save(records, session: session)
        return .result(value: records.enumerated().map { index, record in
            ConnectedDeviceEntity(id: "\(session):\(index)", record: record)
        })
    }
}
