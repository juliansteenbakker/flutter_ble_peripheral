/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */


import Foundation
import CoreBluetooth
import CoreLocation

class FlutterBlePeripheralManager : NSObject {
    
    let stateChangedHandler: StateChangedHandler
    var peripheralManager : CBPeripheralManager!
    
    init(stateChangedHandler: StateChangedHandler) {
        self.stateChangedHandler = stateChangedHandler
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey : true])
    }
    
//    var peripheralData: NSDictionary!

    // min MTU before iOS 10
//    var mtu: Int = 158 {
//        didSet {
//          onMtuChanged?(mtu)
//        }
//    }
    
//    var dataToBeAdvertised: [String: Any]!
//
//    var txCharacteristic: CBMutableCharacteristic?
//    var txSubscribed = false {
//        didSet {
//            if txSubscribed {
//                state = .connected
//            } else if isAdvertising() {
//                state = .advertising
//            }
//        }
//    }
//    var rxCharacteristic: CBMutableCharacteristic?
//
//    var txSubscriptions = Set<UUID>()
    
    /// Set when `start` is called before the manager is powered on. Core Bluetooth
    /// drops an advertisement issued in any other state, so it is kept here and
    /// issued from `peripheralManagerDidUpdateState` once the radio comes up.
    private var pendingAdvertisement: [String: Any]?

    /// Parses a service uuid coming from Dart.
    ///
    /// `CBUUID(string:)` raises an Objective-C exception rather than returning nil
    /// on a string it cannot parse, which cannot be caught from Swift and takes the
    /// process down, so the string is validated first. The 16 bit ("A1B2") and
    /// 32 bit ("A1B2C3D4") short forms are passed through as-is; a 128 bit uuid is
    /// dashed before handing it over, since CBUUID only accepts that form.
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

    func start(advertiseData: FlutterBlePeripheralData) throws {
        var dataToBeAdvertised: [String: Any] = [:]

        // When the plural uuids are set the singular uuid is not used, matching
        // AdvertiseData.serviceUuids and the Android implementation.
        let uuids = advertiseData.uuids ?? advertiseData.uuid.map { [$0] }
        if let uuids = uuids, !uuids.isEmpty {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = try uuids.map {
                guard let uuid = Self.parseServiceUuid($0) else {
                    throw FlutterBlePeripheralError.invalidServiceUuid($0)
                }
                return uuid
            }
        }

        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = advertiseData.localName
        }
        
        print("[flutter_ble_peripheral] start advertising data: \(String(describing: dataToBeAdvertised))")

        guard peripheralManager.state == .poweredOn else {
            // Advertise as soon as the radio is up instead of dropping the call.
            pendingAdvertisement = dataToBeAdvertised
            return
        }

        pendingAdvertisement = nil
        peripheralManager.startAdvertising(dataToBeAdvertised)
        
//         TODO: Add service to advertise
//        if peripheralManager.state == .poweredOn {
//            addService()
//        }
    }

    func stop() {
        // Drop anything queued, so a pending advertisement cannot start after stop.
        pendingAdvertisement = nil
        peripheralManager.stopAdvertising()
    }

    /// Issues the advertisement `start` queued while the radio was still coming up.
    func startPendingAdvertisement() {
        guard let pending = pendingAdvertisement else { return }
        pendingAdvertisement = nil
        peripheralManager.startAdvertising(pending)
    }
    
// TODO: Add service to advertise
//    private func addService() {
//        // Add service and characteristics if needed
//        if txCharacteristic == nil || rxCharacteristic == nil {
//
//            let mutableTxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: PeripheralData.txCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
//            let mutableRxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: PeripheralData.rxCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
//
//            let service = CBMutableService(type: CBUUID(string: PeripheralData.serviceUUID), primary: true)
//            service.characteristics = [mutableTxCharacteristic, mutableRxCharacteristic];
//
//            peripheralManager.add(service)
//
//            self.txCharacteristic = mutableTxCharacteristic
//            self.rxCharacteristic = mutableRxCharacteristic
//        }
//
//        peripheralManager.startAdvertising(dataToBeAdvertised)
//    }
//
//    func send(data: Data) {
//
//        print("[flutter_ble_peripheral] Send data: \(data)")
//
//        guard let characteristic = txCharacteristic else {
//            return
//        }
//
//        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
//    }
}
