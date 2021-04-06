/*
* Copyright (c) 2020. Julian Steenbakker.
* All rights reserved. Use of this source code is governed by a
* BSD-style license that can be found in the LICENSE file.
*/


import Foundation
import CoreBluetooth
import CoreLocation

class Peripheral : NSObject, CBPeripheralManagerDelegate {
    
    let peripheralManager: CBPeripheralManager
    var peripheralData: NSDictionary!
    var onAdvertisingStateChanged: ((Bool) -> Void)?
    var dataToBeAdvertised: [String: [CBUUID]]!
    var shouldStartAdvertise: Bool = false
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func start(advertiseData: AdvertiseData) {
        dataToBeAdvertised = [
            CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: advertiseData.uuid)],
        ]
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
    var uuid: String
    //CBAdvertisementDataLocalNameKey
    var localName: String
    
    init(uuid: String, localName: String) {
        self.uuid = uuid;
        self.localName = localName
    }
}
