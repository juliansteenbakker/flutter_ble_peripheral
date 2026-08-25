//
//  FlutterBlePeripheralManager.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 28/03/2022.
//

import Foundation
import CoreBluetooth
import CoreLocation

/**
 The `FlutterBlePeripheralManager` class manages BLE peripheral functionality
 for the Flutter BLE Peripheral plugin on iOS and macOS.

 **Responsibilities:**
 - Manages the CoreBluetooth `CBPeripheralManager` lifecycle.
 - Handles BLE advertising (start/stop).
 - Sets up and manages GATT services and characteristics (TX/RX).
 - Tracks central device connections and subscriptions.
 - Sends and receives data between peripheral and connected centrals.
 - Reports Bluetooth state, permission state, and MTU changes to Flutter via handlers.

 This class mirrors the Android-side `BlePeripheralManager` and provides a consistent API
 surface for the Flutter plugin across platforms.
 */
class FlutterBlePeripheralManager: NSObject {

    // MARK: - Handlers

    /// Handler that publishes peripheral state changes (e.g., idle, advertising, connected) to Flutter event channels.
    let stateChangedHandler: StateChangedHandler

    // MARK: - Core Bluetooth

    /// The CoreBluetooth peripheral manager instance responsible for advertising and GATT management.
    var peripheralManager: CBPeripheralManager!

    /// Set when advertising is requested before the manager is powered on. Core
    /// Bluetooth drops an advertisement issued in any other state, so it is kept
    /// here and issued from `peripheralManagerDidUpdateState` once the radio is up.
    private var pendingAdvertisement: [String: Any]?

    // MARK: - Initialization

    /**
     Initializes the BLE Peripheral Manager.

     - Parameter stateChangedHandler: Handler that publishes state changes to Flutter.
     */
    init(stateChangedHandler: StateChangedHandler) {
        self.stateChangedHandler = stateChangedHandler
        super.init()

        self.peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [CBPeripheralManagerOptionShowPowerAlertKey: true]
        )
    }

    // MARK: - Advertising

    /**
     Starts BLE advertising with a pre-built advertisement data dictionary.

     This method allows for more fine-grained control over advertisement data,
     including platform-specific settings like manufacturer data, service data, etc.

     - Parameter advertisementData: Complete advertisement data dictionary ready for CBPeripheralManager.
     */
    func startWithAdvertisementData(advertisementData: [String: Any]) {
        print("[flutter_ble_peripheral] Starting advertising with custom data: \(advertisementData)")

        guard peripheralManager.state == .poweredOn else {
            // Advertise as soon as the radio is up instead of dropping the call.
            pendingAdvertisement = advertisementData
            print("[flutter_ble_peripheral] Peripheral manager not powered on yet, advertisement queued")
            return
        }

        pendingAdvertisement = nil
        peripheralManager.startAdvertising(advertisementData)
    }

    // MARK: - Lifecycle Management

    /**
     Stops BLE advertising.
     */
    func stop() {
        // Drop anything queued, so a pending advertisement cannot start after stop.
        pendingAdvertisement = nil
        peripheralManager.stopAdvertising()

        print("[flutter_ble_peripheral] Stopped advertising")
    }

    // MARK: - Bluetooth State and Permissions

    /**
     Returns the current Bluetooth permission state mapped to `PeripheralBluetoothState`.

     On iOS 13+, the system triggers the permission dialog automatically
     when the `CBPeripheralManager` is created and authorization is `.notDetermined`.

     - Returns: The current Bluetooth permission state.
     */
    var permissionState: PeripheralBluetoothState {
        if #available(iOS 13.1, *) {
            switch CBPeripheralManager.authorization {
            case .allowedAlways: return .Granted
            case .denied: return .PermanentlyDenied
            case .restricted: return .Restricted
            case .notDetermined: return .Denied
            @unknown default: return .Unknown
            }
        } else if #available(iOS 13.0, *) {
            switch peripheralManager.authorization {
            case .allowedAlways: return .Granted
            case .denied: return .PermanentlyDenied
            case .restricted: return .Restricted
            case .notDetermined: return .Denied
            @unknown default: return .Unknown
            }
        } else {
            return .Granted // Before iOS 13, permissions not required
        }
    }

    /// Convenience property indicating whether Bluetooth permission has been granted.
    var hasPermissions: Bool {
        return permissionState == .Granted
    }

    /**
     Returns the current Bluetooth adapter state mapped to `PeripheralBluetoothState`.

     Reflects the actual state of the Bluetooth hardware or system stack.

     - Returns: The current adapter state.
     */
    var bluetoothState: PeripheralBluetoothState {
        switch peripheralManager.state {
        case .poweredOn: return .Ready
        case .poweredOff: return .TurnedOff
        case .resetting: return .Unknown
        case .unauthorized: return .Denied
        case .unsupported: return .Unsupported
        case .unknown: return .Unknown
        @unknown default: return .Unknown
        }
    }

    /**
     Returns the combined Bluetooth readiness state,
     taking into account both permission and adapter status.

     - Returns: The overall `PeripheralBluetoothState`.
     */
    func getCombinedState() -> PeripheralBluetoothState {
        let permState = permissionState
        return permState == .Granted ? bluetoothState : permState
    }

    /**
     Attempts to request Bluetooth permission by triggering the system dialog if needed.

     - Parameter completion: Callback invoked with the updated permission state.
     */
    func requestPermission(completion: @escaping (PeripheralBluetoothState) -> Void) {
        switch permissionState {
        case .Denied:
            _ = CBPeripheralManager(delegate: nil, queue: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(self.permissionState)
            }
        default:
            completion(permissionState)
        }
    }

    // MARK: - Service UUID Parsing

    /**
     Parses a service uuid coming from Dart.

     `CBUUID(string:)` raises an Objective-C exception rather than returning nil on
     a string it cannot parse, which cannot be caught from Swift and takes the
     process down, so the string is validated first. The 16 bit ("A1B2") and 32 bit
     ("A1B2C3D4") short forms are passed through as-is; a 128 bit uuid is dashed
     before handing it over, since CBUUID only accepts that form.
     */
    static func parseServiceUuid(_ value: String) -> CBUUID? {
        let hex = value.replacingOccurrences(of: "-", with: "")
        guard hex.allSatisfy(\.isHexDigit) else { return nil }
        switch hex.count {
        case 4, 8:
            return CBUUID(string: hex)
        case 32:
            let dashed = [
                hex.prefix(8),
                hex.dropFirst(8).prefix(4),
                hex.dropFirst(12).prefix(4),
                hex.dropFirst(16).prefix(4),
                hex.dropFirst(20),
            ].joined(separator: "-")
            return CBUUID(string: dashed)
        default:
            return nil
        }
    }

    /// As `parseServiceUuid`, but throws rather than returning nil, so the failure
    /// reaches Dart as a PlatformException.
    static func requireServiceUuid(_ value: String) throws -> CBUUID {
        guard let uuid = parseServiceUuid(value) else {
            throw FlutterBlePeripheralError.invalidServiceUuid(value)
        }
        return uuid
    }

    /// Issues the advertisement that was queued while the radio was still coming up.
    func startPendingAdvertisement() {
        guard let pending = pendingAdvertisement else { return }
        pendingAdvertisement = nil
        peripheralManager.startAdvertising(pending)
    }
}
