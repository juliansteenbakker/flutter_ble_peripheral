/*
* Copyright (c) 2020. Julian Steenbakker.
* All rights reserved. Use of this source code is governed by a
* BSD-style license that can be found in the LICENSE file.
*/


import Foundation
import CoreBluetooth
import CoreLocation

enum PeripheralState {
  case idle, unauthorized, unsupported, advertising, connected
}

class Peripheral : NSObject {
    
    lazy var peripheralManager: CBPeripheralManager  = CBPeripheralManager(delegate: self, queue: nil)
    var peripheralData: NSDictionary!
    
    var state: PeripheralState = .idle {
      didSet {
        onStateChanged?(state)
      }
    }

    var onStateChanged: ((PeripheralState) -> Void)?
    var onDataReceived: ((Data) -> Void)?
    
    var dataToBeAdvertised: [String: Any]!
    var shouldAdvertise = false

    var txCharacteristic: CBMutableCharacteristic?
    var txSubscribed = false
    var rxCharacteristic: CBMutableCharacteristic?
    
    func start(advertiseData: AdvertiseData) {
        
        print("[BLE Peripheral] Start advertising")

        shouldAdvertise = true

        dataToBeAdvertised = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = [advertiseData.localName]
        }

        addService()
    }
    
    func stop() {

        print("[BLE Peripheral] Stop advertising")

        shouldAdvertise = false

        peripheralManager.stopAdvertising()
        state = .idle
    }
    
    func isAdvertising() -> Bool {
        return peripheralManager.isAdvertising
    }

    func isConnected() -> Bool {
        return state == .connected
    }
    
    private func addService() {

      guard shouldAdvertise else {
        return
      }

      let mutableTxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: AdvertiseData.txCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
      let mutableRxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: AdvertiseData.rxCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
      
      self.txCharacteristic = mutableTxCharacteristic
      self.rxCharacteristic = mutableRxCharacteristic

      let service = CBMutableService(type: CBUUID(string: AdvertiseData.serviceUUID), primary: true)
      service.characteristics = [mutableTxCharacteristic, mutableRxCharacteristic];
        
      peripheralManager.add(service)

      peripheralManager.startAdvertising(dataToBeAdvertised)
    }

    func send(data: Data) {
        
        print("[BLE Peripheral] Send data: \(data)")

        guard let characteristic = txCharacteristic else { 
          return 
        }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
}

extension Peripheral: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("[BLE Peripheral] poweredOn")
            addService()
        case .poweredOff:
            print("[BLE Peripheral] poweredOff")
            state = .idle
        case .resetting:
            print("[BLE Peripheral] resetting")
        case .unsupported:
            print("[BLE Peripheral] unsupported")
            state = .unsupported
        case .unauthorized:
            print("[BLE Peripheral] unauthorized")
            state = .unauthorized
        case .unknown:
            print("[BLE Peripheral] unknown")
            state = .idle
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("[BLE Peripheral] didStartAdvertising:", error ?? "success")

        guard error == nil else {
          return
        }

        state = .advertising
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("[BLE Peripheral] didAdd:", service, error ?? "success")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[BLE Peripheral] didReceiveRead:", request)
        
        // Not supported 
        peripheralManager.respond(to: request, withResult: .requestNotSupported)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[BLE Peripheral] didReceiveWrite:", requests)
        
        for request in requests {

            let characteristic = request.characteristic
            guard let data = request.value else {
              return
            }

            if data.count > 0 {

              if characteristic == self.rxCharacteristic {

                print("[BLE Peripheral] Receive data: \(data)")

                onDataReceived?(data)
                peripheralManager.respond(to: request, withResult: .success)
              }
            }

            // Write only supported in rxCharacteristic
            peripheralManager.respond(to: request, withResult: .requestNotSupported)
        }
        
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[BLE Peripheral] didSubscribeTo:", central, characteristic)

        if characteristic == txCharacteristic {
          txSubscribed = true
          state = .connected
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[BLE Peripheral] didUnsubscribeFrom:", central, characteristic)

        if characteristic == txCharacteristic {
          txSubscribed = false
          state = .advertising
        }
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
