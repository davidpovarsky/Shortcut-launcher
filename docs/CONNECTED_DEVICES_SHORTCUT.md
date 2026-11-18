# Get Connected Devices — Shortcuts action (iOS 27)

Action: **Get Connected Devices** (GetConnectedDevicesIntent).

- Returns native [ConnectedDeviceEntity] output for **Choose from List**, **Repeat with Each**, and **Get Details**. Results are timestamped snapshots (entity lookup retained up to 10 minutes); rerun for fresh state.
- Sources: currently active audio inputs/outputs from AVAudioSession.currentRoute (excluding built-in ports), ExternalAccessory.connectedAccessories, system-connected BLE peripherals matching known GATT services, and connected game controllers (GameController).
- For connected controllers, GameController exposes battery level/state when supported; an unknown state is NOT treated as 0%.
- BLE: connect locally (as Apple requires) and read Bluetooth SIG Battery Service 180F / Battery Level 2A19, optional Device Information Service 180A, and RSSI when available.
- Unknown values remain unavailable, never estimated. Multiple separate battery measurements are preserved in Battery Readings rather than claiming a total percentage.
- Limit: iOS public APIs do not enumerate all paired Bluetooth Classic devices or expose Classic headset battery. Sony and other Bluetooth audio headsets may appear as active audio route but usually have battery Not available.
- Bluetooth access requested on first use; permission text localized in InfoPlist.strings. Denied permission blocks BLE reading but not audio route or accessible MFi devices.
- BLE reads are on-demand and bounded to 7 seconds. No background scan and no pairing.
- The app already advertises 10 App Shortcuts (Apple's limit). This is a discoverable AppIntent action, not an additional promoted tile; no existing shortcuts have been removed.

## Device acceptance
1. Install the iOS 27 build and add Dav Launcher > Get Connected Devices to a Shortcut.
2. Connect Bluetooth audio; check the live audio name/source and unavailable battery where appropriate.
3. Connect a BLE accessory that exposes 180F/2A19; check an actual percentage in 0...100, Get Details, Choose from List and Repeat with Each.
4. Check no devices connected and Bluetooth permission denied; no stale devices should be labeled connected.

## Documentation
- https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/retrieveconnectedperipherals(withservices:)
- https://developer.apple.com/documentation/corebluetooth/cbperipheral/readvalue(for:)
- https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription
- https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/connectedaccessories
- https://developer.apple.com/documentation/appintents/defining-app-entities-for-your-custom-data-types
- https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/BAS_v1.1/out/en/index-en.html
