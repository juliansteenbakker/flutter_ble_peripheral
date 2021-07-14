/*
* Copyright (c) 2020. Julian Steenbakker.
* All rights reserved. Use of this source code is governed by a
* BSD-style license that can be found in the LICENSE file.
*/


import Foundation
import CoreBluetooth
import CoreLocation

class Peripheral : NSObject, CBPeripheralManagerDelegate {
    
    lazy var peripheralManager: CBPeripheralManager  = CBPeripheralManager(delegate: self, queue: nil)
    var peripheralData: NSDictionary!
    var onAdvertisingStateChanged: ((Bool) -> Void)?
    var dataToBeAdvertised: [String: [CBUUID]]!
    var shouldStartAdvertise: Bool = false
    
    func start(advertiseData: AdvertiseData) {
        
        dataToBeAdvertised = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = [CBUUID(string: advertiseData.localName!)]
        }
        
        shouldStartAdvertise = true
        peripheralManagerDidUpdateState(peripheralManager)
    }
    
    func stop() {
        print("Stop advertising")
        peripheralManager.stopAdvertising()
        onAdvertisingStateChanged!(false)
    }
    
    func isAdvertising() -> Bool {
        return peripheralManager.isAdvertising
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        onAdvertisingStateChanged!(peripheral.isAdvertising)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if (peripheral.state == .poweredOn && shouldStartAdvertise) {
            print("Start advertising")
            peripheralManager.startAdvertising(dataToBeAdvertised)
            shouldStartAdvertise = false
        }
    }
}

class AdvertiseData {
    var uuid: String?
    var localName: String?     //CBAdvertisementDataLocalNameKey
    
    init(uuid: String?, localName: String?) {
        self.uuid = uuid;
        self.localName = localName
    }
}
