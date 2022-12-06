/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */


import Foundation
import CoreBluetooth
import CoreLocation

class FlutterBlePeripheralManager : NSObject {
    
    var peripheralManager: CBPeripheralManager!
    
    let stateChangedHandler: StateChangedHandler
    
    init(stateChangedHandler: StateChangedHandler) {
        self.stateChangedHandler = stateChangedHandler
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func start(advertiseData: PeripheralData) {
    
        var dataToBeAdvertised: [String: Any]! = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = advertiseData.localName
        }
        
        peripheralManager.startAdvertising(dataToBeAdvertised)
        
//         TODO: Add service to advertise
//        if peripheralManager.state == .poweredOn {
//            addService()
//        }
    }
    
//    lazy var peripheralManager: CBPeripheralManager! = CBPeripheralManager(delegate: self, queue: nil)
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
