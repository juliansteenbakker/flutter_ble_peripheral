/*
* Copyright (c) 2020. Julian Steenbakker.
* All rights reserved. Use of this source code is governed by a
* BSD-style license that can be found in the LICENSE file.
*/


import Foundation
import CoreBluetooth
import CoreLocation

class Peripheral : NSObject, CBPeripheralManagerDelegate {
    
    var peripheralManager: CBPeripheralManager!
    var peripheralData: NSDictionary!
    var onAdvertisingStateChanged: ((Bool) -> Void)?
    var dataToBeAdvertised: [String: [CBUUID]]!
    
    var shouldStartAdvertise: Bool = false
    
    
    func start(advertiseData: AdvertiseData) {
        dataToBeAdvertised = [
            CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: advertiseData.uuid)],
        ]
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        shouldStartAdvertise = true
    }
    
    func stop() {
        if (peripheralManager != nil) {
            peripheralManager.stopAdvertising()
            onAdvertisingStateChanged!(false)
        }
    }
    
    func isAdvertising() -> Bool {
        if (peripheralManager == nil) {
            return false
        }
        return peripheralManager.isAdvertising
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        onAdvertisingStateChanged!(peripheral.isAdvertising)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if (peripheral.state == .poweredOn && shouldStartAdvertise) {
            peripheralManager.startAdvertising(dataToBeAdvertised)
            shouldStartAdvertise = false
        }
    }
}

class AdvertiseData {
    var uuid: String
    var transmissionPower: NSNumber?
//    var identifier: String
    
    init(uuid: String, transmissionPower: NSNumber?) {
        self.uuid = uuid
        self.transmissionPower = transmissionPower
//        self.identifier = identifier
    }
}
