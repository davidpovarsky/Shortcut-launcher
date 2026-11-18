import AVFAudio
import CoreBluetooth
import ExternalAccessory
import Foundation

/// Only PUBLIC iOS APIs. Audio routing has no public battery property;
/// Classic Bluetooth paired-device enumeration is not exposed to apps.
@MainActor
enum ConnectedDeviceCollector {
    static func collect() async -> [ConnectedDeviceRecord] {
        // Collect audio + MFi first, even if Bluetooth authorization is denied.
        var records = audioAccessories() + externalAccessories()
        records += await ConnectedBLEReader().read()
        return records.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func audioAccessories() -> [ConnectedDeviceRecord] {
        let excluded: Set<AVAudioSession.Port> = [.builtInSpeaker, .builtInReceiver, .builtInMic]
        let route = AVAudioSession.sharedInstance().currentRoute
        // Inputs/outputs are not merged blindly: the same accessory may be both.
        var ports: [AVAudioSessionPortDescription] = []
        var seen = Set<String>()
        for port in route.outputs + route.inputs where !excluded.contains(port.portType) {
            if seen.insert(port.uid).inserted { ports.append(port) }
        }
        return ports.map { port in
            ConnectedDeviceRecord(
                name: port.portName,
                kind: "Audio accessory",
                source: "Active audio route (AVAudioSession)",
                audioPortUID: port.uid,
                audioPortType: port.portType.rawValue
            )
        }
    }

    private static func externalAccessories() -> [ConnectedDeviceRecord] {
        EAAccessoryManager.shared().connectedAccessories.filter(\.isConnected).map { accessory in
            ConnectedDeviceRecord(
                name: accessory.name,
                kind: "External accessory",
                source: "ExternalAccessory",
                manufacturer: accessory.manufacturer,
                model: accessory.modelNumber,
                serialNumber: accessory.serialNumber,
                firmwareVersion: accessory.firmwareRevision,
                hardwareVersion: accessory.hardwareRevision,
                accessoryProtocols: accessory.protocolStrings
            )
        }
    }
}

/// Read the Bluetooth SIG Battery Service (180F/2A19) and, when published,
/// optional GATT device information, for BLE devices already connected to iOS.
/// This is NOT a Bluetooth Classic device list or a scan of nearby devices.
///
/// The @preconcurrency delegate conformances are intentional: CoreBluetooth
/// callbacks are scheduled on .main, which is the actor used for all state.
@MainActor
final class ConnectedBLEReader: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    private static let batteryService = CBUUID(string: "180F")
    private static let deviceInfoService = CBUUID(string: "180A")
    private static let batteryLevelChar = CBUUID(string: "2A19")
    private static let infoChars = [
        CBUUID(string: "2A29"), // Manufacturer
        CBUUID(string: "2A24"), // Model
        CBUUID(string: "2A25"), // Serial
        CBUUID(string: "2A26"), // Firmware
        CBUUID(string: "2A27")  // Hardware
    ]

    // retrieveConnectedPeripherals *requires* matching GATT service UUIDs.
    // There is no public "all connected Bluetooth devices" API.
    private static let lookupServices = [
        "180F", "180A", "1800", "1801", "1812", "180D", "1809",
        "1816", "181A", "1826", "1810", "1808", "1805", "1818", "1814"
    ].map(CBUUID.init(string:))

    private var central: CBCentralManager?
    private var continuation: CheckedContinuation<[ConnectedDeviceRecord], Never>?
    private var discovered: [UUID: CBPeripheral] = [:]
    private var observations: [UUID: ConnectedDeviceRecord] = [:]
    private var inProgress: Set<UUID> = []
    private var outstandingServices: [UUID: Int] = [:]
    private var outstandingValues: [UUID: Int] = [:]
    private var timeoutTask: Task<Void, Never>?

    func read() async -> [ConnectedDeviceRecord] {
        guard CBCentralManager.authorization != .denied,
              CBCentralManager.authorization != .restricted else { return [] }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            central = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(7))
                self?.finish()
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard continuation != nil else { return }
        switch central.state {
        case .poweredOn:
            let peripherals = central.retrieveConnectedPeripherals(withServices: Self.lookupServices)
            for peripheral in peripherals where discovered[peripheral.identifier] == nil {
                let id = peripheral.identifier
                discovered[id] = peripheral
                observations[id] = ConnectedDeviceRecord(
                    name: peripheral.name ?? "Unnamed BLE device",
                    kind: "Bluetooth LE",
                    source: "CoreBluetooth (GATT)",
                    bluetoothIdentifier: id.uuidString
                )
                inProgress.insert(id)
                peripheral.delegate = self
                // Local connection required even when another app is connected.
                central.connect(peripheral, options: nil)
            }
            if inProgress.isEmpty { finish() }
        case .unknown, .resetting:
            break
        default:
            finish()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard continuation != nil else { return }
        peripheral.readRSSI()
        peripheral.discoverServices([Self.batteryService, Self.deviceInfoService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finishedPeripheral(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if continuation != nil { finishedPeripheral(peripheral) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard continuation != nil else { return }
        let services = error == nil ? (peripheral.services ?? []) : []
        observations[peripheral.identifier]?.services = services.map { $0.uuid.uuidString }
        outstandingServices[peripheral.identifier] = services.count
        outstandingValues[peripheral.identifier] = 0
        for service in services {
            if service.uuid == Self.batteryService {
                peripheral.discoverCharacteristics([Self.batteryLevelChar], for: service)
            } else if service.uuid == Self.deviceInfoService {
                peripheral.discoverCharacteristics(Self.infoChars, for: service)
            } else {
                outstandingServices[peripheral.identifier, default: 0] -= 1
            }
        }
        completeIfReady(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard continuation != nil else { return }
        outstandingServices[peripheral.identifier, default: 0] -= 1
        if error == nil {
            for characteristic in service.characteristics ?? []
            where characteristic.properties.contains(.read) {
                outstandingValues[peripheral.identifier, default: 0] += 1
                peripheral.readValue(for: characteristic)
            }
        }
        completeIfReady(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard continuation != nil else { return }
        outstandingValues[peripheral.identifier, default: 0] -= 1
        if error == nil, var record = observations[peripheral.identifier] {
            switch characteristic.uuid.uuidString.uppercased() {
            case "2A19":
                if let level = ConnectedDeviceValueDecoder.batteryLevel(characteristic.value) {
                    record.batteryLevels.append(level)
                }
            case "2A29": record.manufacturer = ConnectedDeviceValueDecoder.deviceText(characteristic.value)
            case "2A24": record.model = ConnectedDeviceValueDecoder.deviceText(characteristic.value)
            case "2A25": record.serialNumber = ConnectedDeviceValueDecoder.deviceText(characteristic.value)
            case "2A26": record.firmwareVersion = ConnectedDeviceValueDecoder.deviceText(characteristic.value)
            case "2A27": record.hardwareVersion = ConnectedDeviceValueDecoder.deviceText(characteristic.value)
            default: break
            }
            observations[peripheral.identifier] = record
        }
        completeIfReady(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        observations[peripheral.identifier]?.signalStrengthDBm = RSSI.intValue
    }

    private func completeIfReady(_ peripheral: CBPeripheral) {
        guard outstandingServices[peripheral.identifier, default: 0] == 0,
              outstandingValues[peripheral.identifier, default: 0] == 0 else { return }
        finishedPeripheral(peripheral)
    }

    private func finishedPeripheral(_ peripheral: CBPeripheral) {
        guard inProgress.remove(peripheral.identifier) != nil else { return }
        central?.cancelPeripheralConnection(peripheral)
        if inProgress.isEmpty { finish() }
    }

    private func finish() {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        for (_, peripheral) in discovered {
            central?.cancelPeripheralConnection(peripheral)
            peripheral.delegate = nil
        }
        central?.delegate = nil
        central = nil
        continuation.resume(returning: Array(observations.values))
    }
}
