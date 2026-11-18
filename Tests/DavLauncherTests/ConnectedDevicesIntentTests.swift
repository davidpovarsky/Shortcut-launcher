import Foundation
import XCTest
@testable import DavLauncher

final class ConnectedDevicesIntentTests: XCTestCase {
    func testBatteryLevelDecodingDoesNotInventMissingValues() {
        XCTAssertEqual(ConnectedDeviceValueDecoder.batteryLevel(Data([0])), 0)
        XCTAssertEqual(ConnectedDeviceValueDecoder.batteryLevel(Data([75])), 75)
        XCTAssertEqual(ConnectedDeviceValueDecoder.batteryLevel(Data([100])), 100)
        XCTAssertNil(ConnectedDeviceValueDecoder.batteryLevel(Data([101])))
        XCTAssertNil(ConnectedDeviceValueDecoder.batteryLevel(Data([0xFF])))
        XCTAssertNil(ConnectedDeviceValueDecoder.batteryLevel(Data()))
        XCTAssertNil(ConnectedDeviceValueDecoder.batteryLevel(Data([30, 40])))
        XCTAssertNil(ConnectedDeviceValueDecoder.batteryLevel(nil))
    }

    func testDeviceInfoOnlyAcceptsNonemptyUTF8() {
        XCTAssertEqual(ConnectedDeviceValueDecoder.deviceText(Data("Sony".utf8)), "Sony")
        XCTAssertNil(ConnectedDeviceValueDecoder.deviceText(Data()))
        XCTAssertNil(ConnectedDeviceValueDecoder.deviceText(Data([0xFF, 0xFE])))
        XCTAssertNil(ConnectedDeviceValueDecoder.deviceText(Data("  \n ".utf8)))
    }

    func testMultipleBatteryReadingsAreNotMisrepresentedAsOneBattery() {
        var record = ConnectedDeviceRecord(name: "Earbuds", kind: "BLE", source: "GATT")
        XCTAssertNil(record.batteryPercentage)
        XCTAssertEqual(record.batteryDescription, "Not available")
        record.batteryLevels = [60]
        XCTAssertEqual(record.batteryPercentage, 60)
        record.batteryLevels = [60, 75]
        XCTAssertNil(record.batteryPercentage)
        XCTAssertEqual(record.batteryDescription, "60%, 75%")
    }

    func testSnapshotResolutionPreservesMetadataAndSafeIDs() throws {
        let session = UUID().uuidString
        var record = ConnectedDeviceRecord(name: "Test accessory", kind: "Bluetooth LE", source: "GATT")
        record.batteryLevels = [90]
        record.manufacturer = "Example"
        record.firmwareVersion = "1.2.3"
        record.bluetoothIdentifier = UUID().uuidString
        try ConnectedDeviceSnapshotStore.save([record], session: session)
        let entityID = "\(session):0"
        let entity = try XCTUnwrap(ConnectedDeviceSnapshotStore.resolve([entityID]).first)
        XCTAssertEqual(entity.name, "Test accessory")
        XCTAssertEqual(entity.batteryPercentage, 90)
        XCTAssertEqual(entity.batteryReadings, "90%")
        XCTAssertEqual(entity.manufacturer, "Example")
        XCTAssertEqual(entity.firmwareVersion, "1.2.3")
        XCTAssertEqual(entity.bluetoothIdentifier, record.bluetoothIdentifier)
        XCTAssertTrue(ConnectedDeviceSnapshotStore.resolve(["\(session):1"]).isEmpty)
        XCTAssertTrue(ConnectedDeviceSnapshotStore.resolve(["not-a-session"]).isEmpty)
    }

    func testLiveDevicesAreNotSuggestedFromCache() async throws {
        let suggestions = try await ConnectedDeviceEntityQuery().suggestedEntities()
        XCTAssertTrue(suggestions.isEmpty)
    }
}
