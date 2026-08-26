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

    /// Handler that publishes data received from connected central devices to Flutter event channels.
    let dataReceivedHandler: DataReceivedHandler?

    /// Handler that publishes MTU (Maximum Transmission Unit) updates to Flutter event channels.
    let mtuChangedHandler: MtuChangedHandler?

    /// Handler that publishes TX subscription changes to Flutter event channels.
    let subscriptionChangedHandler: SubscriptionChangedHandler?

    // MARK: - Core Bluetooth

    /// The CoreBluetooth peripheral manager instance responsible for advertising and GATT management.
    var peripheralManager: CBPeripheralManager!

    // MARK: - GATT Attributes

    /// The currently active GATT service.
    var currentService: CBMutableService?

    /// The transmit (TX) characteristic for sending data to centrals.
    var txCharacteristic: CBMutableCharacteristic?

    /// The receive (RX) characteristic for receiving data from centrals.
    var rxCharacteristic: CBMutableCharacteristic?

    /// The GATT service to add once the peripheral manager powers on.
    var pendingGattService: GattServiceRequest?

    /// Set when advertising is requested before the manager is powered on. Core
    /// Bluetooth drops an advertisement issued in any other state, so it is kept
    /// here and issued from `peripheralManagerDidUpdateState` once the radio is up.
    private var pendingAdvertisement: [String: Any]?

    // MARK: - Connection Tracking

    /// Set of UUIDs representing centrals subscribed to the TX characteristic.
    var txSubscriptions = Set<UUID>()

    /// Set of UUIDs representing currently connected centrals.
    var connectedCentrals = Set<UUID>()

    // MARK: - MTU Tracking

    /// The largest notification payload a subscribed central will take, which is
    /// what Core Bluetooth reports. Default is 158 (minimum supported before iOS 10).
    ///
    /// Dart is given the ATT MTU, three bytes larger for the header, since that is
    /// what Android and Windows send.
    var maximumNotificationSize: Int = 158 {
        didSet {
            mtuChangedHandler?.publishMtu(mtu: maximumNotificationSize + 3)
        }
    }

    /// Indicates whether any central has subscribed to TX notifications.
    /// Updates the published peripheral state accordingly.
    var txSubscribed = false {
        didSet {
            guard txSubscribed != oldValue else { return }
            subscriptionChangedHandler?.publish(subscribed: txSubscribed)
            if txSubscribed {
                stateChangedHandler.publishPeripheralState(state: .connected)
            } else if peripheralManager.isAdvertising {
                stateChangedHandler.publishPeripheralState(state: .advertising)
            }
        }
    }

    // MARK: - Notification Queue

    /**
     Payloads waiting to go out.

     `updateValue` returns false when Core Bluetooth's transmit queue is full,
     and the payload is dropped; the queue is drained again from
     `peripheralManagerIsReadyToUpdateSubscribers`.
     */
    private var notifyQueue: [Data] = []

    /// The last payload `sendData` was given, returned to a central that reads TX.
    private var lastSentValue: Data?

    // MARK: - Initialization

    /**
     Initializes the BLE Peripheral Manager.

     - Parameters:
       - stateChangedHandler: Handler that publishes state changes to Flutter.
       - dataReceivedHandler: Handler that publishes received data to Flutter.
       - mtuChangedHandler: Handler that publishes MTU change events to Flutter.
       - subscriptionChangedHandler: Handler that publishes TX subscription changes.
     */
    init(
        stateChangedHandler: StateChangedHandler,
        dataReceivedHandler: DataReceivedHandler?,
        mtuChangedHandler: MtuChangedHandler?,
        subscriptionChangedHandler: SubscriptionChangedHandler?
    ) {
        self.stateChangedHandler = stateChangedHandler
        self.dataReceivedHandler = dataReceivedHandler
        self.mtuChangedHandler = mtuChangedHandler
        self.subscriptionChangedHandler = subscriptionChangedHandler
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

     - Parameters:
       - advertisementData: Complete advertisement data dictionary ready for CBPeripheralManager.
       - gattService: The service to serve alongside it, or nil to advertise only.
     */
    func startWithAdvertisementData(
        advertisementData: [String: Any],
        gattService: GattServiceRequest? = nil
    ) {
        print("[flutter_ble_peripheral] Starting advertising with custom data: \(advertisementData)")

        guard peripheralManager.state == .poweredOn else {
            // Advertise as soon as the radio is up instead of dropping the call.
            pendingAdvertisement = advertisementData
            pendingGattService = gattService
            print("[flutter_ble_peripheral] Peripheral manager not powered on yet, advertisement queued")
            return
        }

        pendingAdvertisement = nil
        pendingGattService = nil
        peripheralManager.startAdvertising(advertisementData)

        if let gattService = gattService {
            addService(gattService)
        }
    }

    // MARK: - GATT Service Management

    /**
     Adds the GATT service Dart asked for, with its TX and RX characteristics.

     - Parameter request: The service and characteristic uuids chosen by the caller.
     */
    func addService(_ request: GattServiceRequest) {
        let serviceUuid = request.serviceUuid
        let txUuid = request.txCharacteristicUuid
        let rxUuid = request.rxCharacteristicUuid

        // TX characteristic: notify central devices of updates
        let mutableTxCharacteristic = CBMutableCharacteristic(
            type: CBUUID(string: txUuid),
            properties: [.read, .notify, .indicate],
            value: nil,
            permissions: [.readable]
        )

        // RX characteristic: receive data from central devices
        let mutableRxCharacteristic = CBMutableCharacteristic(
            type: CBUUID(string: rxUuid),
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        // Create and add service
        let service = CBMutableService(type: CBUUID(string: serviceUuid), primary: true)
        service.characteristics = [mutableTxCharacteristic, mutableRxCharacteristic]

        peripheralManager.add(service)

        self.currentService = service
        self.txCharacteristic = mutableTxCharacteristic
        self.rxCharacteristic = mutableRxCharacteristic

        print("[flutter_ble_peripheral] GATT service added: \(serviceUuid) with TX: \(txUuid), RX: \(rxUuid)")
    }

    // MARK: - Data Transmission

    /**
     Sends data to connected central devices via the TX characteristic.

     - Parameter data: The binary payload to send.
     - Returns: `true` if the data was successfully transmitted, otherwise `false`.
     */
    func sendData(data: Data) -> Bool {
        print("[flutter_ble_peripheral] Send data: \(data.count) bytes")

        guard txCharacteristic != nil else {
            print("[flutter_ble_peripheral] Cannot send data: No TX characteristic")
            return false
        }

        guard txSubscribed else {
            print("[flutter_ble_peripheral] Cannot send data: no central is subscribed")
            return false
        }

        lastSentValue = data
        notifyQueue.append(data)
        drainNotifyQueue()
        return true
    }

    /**
     Sends as much of the queue as Core Bluetooth will take.

     `updateValue` returns false once its transmit queue is full, and drops that
     payload. Anything still queued waits for
     `peripheralManagerIsReadyToUpdateSubscribers`.
     */
    func drainNotifyQueue() {
        guard let characteristic = txCharacteristic else { return }

        while let next = notifyQueue.first {
            let sent = peripheralManager.updateValue(
                next,
                for: characteristic,
                onSubscribedCentrals: nil
            )
            if !sent {
                print("[flutter_ble_peripheral] Transmit queue full, \(notifyQueue.count) payload(s) waiting")
                return
            }
            notifyQueue.removeFirst()
        }
    }

    /// The value a central gets when it reads [uuid], or nil when it is not a
    /// characteristic this peripheral serves a value for.
    func readValue(for uuid: CBUUID) -> Data? {
        guard uuid == txCharacteristic?.uuid else { return nil }
        return lastSentValue
    }

    // MARK: - Lifecycle Management

    /**
     Stops BLE advertising and removes all GATT services.

     This also clears active connections and subscriptions.
     */
    func stop() {
        // Drop anything queued, so a pending advertisement cannot start after stop.
        pendingAdvertisement = nil
        peripheralManager.stopAdvertising()

        if let service = currentService {
            peripheralManager.remove(service)
        }

        currentService = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        txSubscriptions.removeAll()
        connectedCentrals.removeAll()
        txSubscribed = false
        pendingGattService = nil
        notifyQueue.removeAll()
        lastSentValue = nil

        print("[flutter_ble_peripheral] Stopped advertising and removed services")
    }

    /**
     Returns whether any central devices are currently connected.

     - Returns: `true` if one or more centrals are connected, otherwise `false`.
     */
    func hasConnectedDevices() -> Bool {
        return !connectedCentrals.isEmpty
    }

    /**
     Returns whether any central subscribed to the TX characteristic, which is
     the state in which `sendData` can deliver.
     */
    func hasSubscribedCentrals() -> Bool {
        return !txSubscriptions.isEmpty
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

        if let gattService = pendingGattService {
            pendingGattService = nil
            addService(gattService)
        }
    }
}
