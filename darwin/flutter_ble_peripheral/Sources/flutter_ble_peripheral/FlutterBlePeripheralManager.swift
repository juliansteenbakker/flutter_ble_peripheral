//
//  FlutterBlePeripheralManager.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 28/03/2022.
//

import Foundation
import CoreBluetooth

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

    /// The identifier Core Bluetooth hands the advertisement and the served
    /// services back under, after it relaunched the app into the background.
    static let restoreIdentifier = "dev.steenbakker.flutter_ble_peripheral.peripheral_manager"

    /// Whether the app declares the `bluetooth-peripheral` background mode, which
    /// is what keeps the advertisement on air once the app is no longer in front,
    /// and what lets Core Bluetooth relaunch the app to hand its state back.
    static var declaresPeripheralBackgroundMode: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("bluetooth-peripheral") ?? false
    }

    // MARK: - GATT Attributes

    /// The currently active GATT service.
    var currentService: CBMutableService?

    /// The characteristics being served, by uuid.
    var servedCharacteristics: [CBUUID: CBMutableCharacteristic] = [:]

    /// The uuids `sendData` can deliver on.
    var notifyingUuids: Set<CBUUID> = []

    /// The uuids a central may write to.
    var writableUuids: Set<CBUUID> = []

    /// The GATT service to add once the peripheral manager powers on.
    var pendingGattService: GattServiceRequest?

    /// Set when advertising is requested before the manager is powered on. Core
    /// Bluetooth drops an advertisement issued in any other state, so it is kept
    /// here and issued from `peripheralManagerDidUpdateState` once the radio is up.
    private var pendingAdvertisement: [String: Any]?

    // MARK: - Connection Tracking

    /**
     The centrals subscribed to each notifying characteristic.

     Per characteristic rather than one set, since a central may take one
     characteristic of a service and leave another, and `sendData` may only
     notify those that asked for the one it is sending on.
     */
    var subscriptions: [CBUUID: Set<UUID>] = [:]

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

    /// Whether any central is subscribed to any notifying characteristic, which
    /// is the state in which `sendData` can deliver at all.
    var anySubscribed: Bool {
        subscriptions.values.contains { !$0.isEmpty }
    }

    /**
     Publishes the subscription state of one characteristic, and moves the
     peripheral state with the aggregate.
     */
    func publishSubscription(_ uuid: CBUUID) {
        let subscribed = !(subscriptions[uuid]?.isEmpty ?? true)
        let any = anySubscribed
        subscriptionChangedHandler?.publish(
            characteristicUuid: uuid,
            subscribed: subscribed,
            anySubscribed: any
        )
        if any {
            stateChangedHandler.publishPeripheralState(state: .connected)
        } else if peripheralManager.isAdvertising {
            stateChangedHandler.publishPeripheralState(state: .advertising)
        }
    }

    // MARK: - Notification Queue

    /**
     Payloads waiting to go out, per characteristic.

     `updateValue` returns false when Core Bluetooth's transmit queue is full,
     and the payload is dropped; the queue is drained again from
     `peripheralManagerIsReadyToUpdateSubscribers`.
     */
    private var notifyQueues: [CBUUID: [Data]] = [:]

    /// The last payload `sendData` was given per characteristic, returned to a
    /// central that reads that one.
    private var lastSentValues: [CBUUID: Data] = [:]

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

        var options: [String: Any] = [CBPeripheralManagerOptionShowPowerAlertKey: true]
#if os(iOS)
        // Only an app that advertises in the background is ever relaunched to be
        // handed its state back, so the identifier is set exactly when it asked for
        // that. Handing one to an app without the background mode would make Core
        // Bluetooth keep state it can never restore.
        if FlutterBlePeripheralManager.declaresPeripheralBackgroundMode {
            options[CBPeripheralManagerOptionRestoreIdentifierKey] =
                FlutterBlePeripheralManager.restoreIdentifier
        }
#endif

        self.peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: options
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

        // Core Bluetooth answers a second startAdvertising with "advertising is
        // already started" and keeps what it has, rather than replacing it, so it is
        // stopped first. An app that comes back from a background relaunch is in
        // exactly that state before it starts again.
        if peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
        }
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

        // A restored service is already being served, and adding the same layout a
        // second time fails, so it is left alone. A different layout replaces it.
        if let existing = currentService {
            let sameLayout = serviceUuid == existing.uuid
                && Set(request.characteristics.map(\.uuid)) == Set(servedCharacteristics.keys)
            if sameLayout {
                print("[flutter_ble_peripheral] GATT service \(serviceUuid) is already served")
                return
            }
            peripheralManager.remove(existing)
        }

        servedCharacteristics = [:]
        notifyingUuids = []
        writableUuids = []

        var characteristics: [CBMutableCharacteristic] = []
        for wanted in request.characteristics {
            let characteristic = CBMutableCharacteristic(
                type: wanted.uuid,
                properties: wanted.coreProperties,
                value: nil,
                permissions: wanted.corePermissions
            )
            characteristics.append(characteristic)
            servedCharacteristics[wanted.uuid] = characteristic
            if wanted.canNotify { notifyingUuids.insert(wanted.uuid) }
            if wanted.canWrite { writableUuids.insert(wanted.uuid) }
        }

        let service = CBMutableService(type: serviceUuid, primary: true)
        service.characteristics = characteristics

        peripheralManager.add(service)

        self.currentService = service

        print("[flutter_ble_peripheral] GATT service added: \(serviceUuid) with "
              + "\(characteristics.count) characteristic(s)")
    }

    // MARK: - Data Transmission

    /**
     Sends data to connected central devices via the TX characteristic.

     - Parameter data: The binary payload to send.
     - Returns: `true` if the data was successfully transmitted, otherwise `false`.
     */
    func sendData(data: Data, characteristicUuid: CBUUID? = nil) -> SendResult {
        print("[flutter_ble_peripheral] Send data: \(data.count) bytes")

        guard !notifyingUuids.isEmpty else {
            print("[flutter_ble_peripheral] Cannot send data: no GATT server is running")
            return .noServer
        }

        // Without a uuid there is an answer only while the service notifies on
        // exactly one characteristic, which is the case for the default pair.
        let uuid: CBUUID
        if let named = characteristicUuid {
            uuid = named
        } else if notifyingUuids.count == 1, let only = notifyingUuids.first {
            uuid = only
        } else {
            return .ambiguousCharacteristic
        }

        guard notifyingUuids.contains(uuid) else {
            print("[flutter_ble_peripheral] Cannot send data: \(uuid) does not notify")
            return .unknownCharacteristic
        }

        guard !(subscriptions[uuid]?.isEmpty ?? true) else {
            print("[flutter_ble_peripheral] Cannot send data: nobody is subscribed to \(uuid)")
            return .notSubscribed
        }

        lastSentValues[uuid] = data
        notifyQueues[uuid, default: []].append(data)
        drainNotifyQueue(for: uuid)
        return .sent
    }

    /**
     Sends as much of the queue as Core Bluetooth will take.

     `updateValue` returns false once its transmit queue is full, and drops that
     payload. Anything still queued waits for
     `peripheralManagerIsReadyToUpdateSubscribers`.
     */
    func drainNotifyQueue(for uuid: CBUUID) {
        guard let characteristic = servedCharacteristics[uuid] else { return }

        while let next = notifyQueues[uuid]?.first {
            let sent = peripheralManager.updateValue(
                next,
                for: characteristic,
                onSubscribedCentrals: nil
            )
            if !sent {
                let waiting = notifyQueues[uuid]?.count ?? 0
                print("[flutter_ble_peripheral] Transmit queue full, \(waiting) payload(s) waiting")
                return
            }
            notifyQueues[uuid]?.removeFirst()
        }
    }

    /**
     Drains every characteristic's queue.

     Core Bluetooth does not say which characteristic freed up when it reports it
     can take more, so all of them are tried.
     */
    func drainNotifyQueues() {
        for uuid in notifyQueues.keys {
            drainNotifyQueue(for: uuid)
        }
    }

    /// The value a central gets when it reads [uuid], or nil when nothing has
    /// been sent on that characteristic.
    func readValue(for uuid: CBUUID) -> Data? {
        lastSentValues[uuid]
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
        servedCharacteristics.removeAll()
        notifyingUuids.removeAll()
        writableUuids.removeAll()
        subscriptions.removeAll()
        connectedCentrals.removeAll()
        pendingGattService = nil
        notifyQueues.removeAll()
        lastSentValues.removeAll()

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
     Returns whether any central subscribed to a notifying characteristic, which
     is the state in which `sendData` can deliver.
     */
    func hasSubscribedCentrals() -> Bool {
        return anySubscribed
    }

    /// Returns whether any central is subscribed to [uuid].
    func hasSubscribedCentrals(for uuid: CBUUID) -> Bool {
        return !(subscriptions[uuid]?.isEmpty ?? true)
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

    /**
     The canonical lowercase 128 bit form, which is what Dart is told a write or
     a subscription landed on.

     A uuid configured as `"2a37"` comes back from Core Bluetooth in that short
     form, and Android and Windows both report the long one, so it is expanded
     here rather than leaving Dart to compare two spellings of one uuid.
     */
    static func fullUuid(_ uuid: CBUUID) -> String {
        let text = uuid.uuidString.lowercased()
        switch text.count {
        case 4:
            return "0000\(text)-0000-1000-8000-00805f9b34fb"
        case 8:
            return "\(text)-0000-1000-8000-00805f9b34fb"
        default:
            return text
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

    // MARK: - Background Restoration

    /**
     Takes back the advertisement and the service Core Bluetooth kept running while
     the app was not there, after it relaunched the app into the background.

     The advertisement is already on air by the time this is called, so it is not
     started again; what is missing is everything this class tracks about it, which
     the restored service and its subscribed centrals give back.
     */
    func restoreState(_ state: [String: Any]) {
        let services = state[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []

        guard let service = services.first else { return }
        currentService = service

        // The layout comes back with the service, so what each characteristic
        // allows is read off its own properties rather than from Dart, which has
        // not asked for anything yet at this point.
        for characteristic in service.characteristics?
            .compactMap({ $0 as? CBMutableCharacteristic }) ?? [] {
            servedCharacteristics[characteristic.uuid] = characteristic

            if characteristic.properties.contains(.notify)
                || characteristic.properties.contains(.indicate) {
                notifyingUuids.insert(characteristic.uuid)

                // The centrals that were subscribed come back too, and that is
                // what decides whether sendData can deliver.
                let subscribed = characteristic.subscribedCentrals ?? []
                subscriptions[characteristic.uuid] = Set(subscribed.map { $0.identifier })
                connectedCentrals.formUnion(subscribed.map { $0.identifier })
                if let central = subscribed.first {
                    maximumNotificationSize = central.maximumUpdateValueLength
                }
            }

            if characteristic.properties.contains(.write)
                || characteristic.properties.contains(.writeWithoutResponse) {
                writableUuids.insert(characteristic.uuid)
            }
        }

        for uuid in notifyingUuids where !(subscriptions[uuid]?.isEmpty ?? true) {
            publishSubscription(uuid)
        }

        print("[flutter_ble_peripheral] Restored \(servedCharacteristics.count) characteristic(s), "
              + "\(connectedCentrals.count) central(s)")
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
