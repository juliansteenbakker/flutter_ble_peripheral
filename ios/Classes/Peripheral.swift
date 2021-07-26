/*
* Copyright (c) 2020. Julian Steenbakker.
* All rights reserved. Use of this source code is governed by a
* BSD-style license that can be found in the LICENSE file.
*/


import Foundation
import CoreBluetooth
import CoreLocation

class Peripheral : NSObject {
    
    lazy var peripheralManager: CBPeripheralManager  = CBPeripheralManager(delegate: self, queue: nil)
    var peripheralData: NSDictionary!
    var onAdvertisingStateChanged: ((Bool) -> Void)?
    var dataToBeAdvertised: [String: Any]!

    var txCharacteristic: CBMutableCharacteristic?
    var rxCharacteristic: CBMutableCharacteristic?
    
    func start(advertiseData: AdvertiseData) {
        
        dataToBeAdvertised = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = [advertiseData.localName]
        }

        peripheralManager.startAdvertising(dataToBeAdvertised)
    }
    
    func stop() {
        print("Stop advertising")
        peripheralManager.stopAdvertising()
        onAdvertisingStateChanged!(false)
    }
    
    func isAdvertising() -> Bool {
        return peripheralManager.isAdvertising
    }
    
    private func addService() {

      let mutableTxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: AdvertiseData.txCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
      let mutableRxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: AdvertiseData.rxCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
      
      self.txCharacteristic = mutableTxCharacteristic
      self.rxCharacteristic = mutableRxCharacteristic

      let service = CBMutableService(type: CBUUID(string: AdvertiseData.serviceUUID), primary: true)
      service.characteristics = [mutableTxCharacteristic, mutableRxCharacteristic];
        
      peripheralManager.add(service)
    }

    func updateValue(data: Data) {
        
        guard let characteristic = txCharacteristic else { 
          return 
        }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }

//     - (void)sendData:(NSData *)data
// {
//     NSLog(@"sendData: %@", data);
    
//     if (self.peripheral && self.rxCharacteristic)
//     {
//         // Act as central
//         // IMPORTANT use the RX characteristic of peripheral
//         [self.peripheral writeValue:data forCharacteristic:self.rxCharacteristic type:CBCharacteristicWriteWithResponse];
        
//     }
//     else if (self.mutableTxCharacteristic)
//     {
//         // Act as peripheral
//         [self.peripheralManager updateValue:data forCharacteristic:self.mutableTxCharacteristic onSubscribedCentrals:nil];
//     }
// }
}

extension Peripheral: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("poweredOn")
            addService()
        case .poweredOff:
            print("poweredOff")
        case .resetting:
            print("resetting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauthorized")
        case .unknown:
            print("unknown")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("didStartAdvertising:", error ?? "success")
        onAdvertisingStateChanged!(peripheral.isAdvertising)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("didAdd:", service, error ?? "success")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("didReceiveRead:", request)
        
        // Not supported 
        peripheralManager.respond(to: request, withResult: .requestNotSupported)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("didReceiveWrite:", requests)
        
        for request in requests {

            let characteristic = request.characteristic
            guard let data = request.value else {
              return
            }

            if data.count > 0 {

              // TODO check characteristic == rxCharacteristic
              //if (characteristic == self.mutableRxCharacteristic)
              //{
              //  [self didReceiveData:data];
              //}
  
              peripheralManager.respond(to: request, withResult: .success)
            }
        }
        
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("didSubscribeTo:", central, characteristic)

        // TEST
        let testString = "hello world"
        updateValue(data: testString.data(using: .utf8)!)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("didUnsubscribeFrom:", central, characteristic)
    }
}

class AdvertiseData {
    var uuid: String?
    var localName: String?     //CBAdvertisementDataLocalNameKey
    
    static let serviceUUID: String = "8ebdb2f3-7817-45c9-95c5-c5e9031aaa47"
    static let txCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D4"
    static let rxCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D5"

    init(uuid: String?, localName: String?) {
        self.uuid = Self.serviceUUID //uuid;
        self.localName = localName
    }
}
