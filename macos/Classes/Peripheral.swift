/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */


import Foundation
import CoreBluetooth

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

    // min MTU before iOS 10
    var mtu: Int = 158 {
        didSet {
          print("[BLE] mtu:", mtu);
          onMtuChanged?(mtu)
        }
    }
    
    var onStateChanged: ((PeripheralState) -> Void)?
    var onMtuChanged: ((Int) -> Void)?
    var onDataReceived: ((Data) -> Void)?
    
    var dataToBeAdvertised: [String: Any]!
    
    var shouldStartAdvertising = false
    
    var txCharacteristic: CBMutableCharacteristic?
    var txSubscribed = false {
        didSet {
            print("[BLE Peripheral] txSubscribed = ", txSubscribed)
            if txSubscribed {
                state = .connected
            } else if isAdvertising() {
                state = .advertising
            }
        }
    }
    var rxCharacteristic: CBMutableCharacteristic?
    
    var txSubscriptions = Set<UUID>()
    
    func start(advertiseData: AdvertiseData) {
        
        print("[BLE Peripheral] Start advertising")
        
        dataToBeAdvertised = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = [advertiseData.localName]
        }
        
        shouldStartAdvertising = true
        
        if peripheralManager.state == .poweredOn {
            addService()
        }
    }
    
    func stop() {
        
        print("[BLE Peripheral] Stop advertising")
        
        shouldStartAdvertising = false
        
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
        
        guard shouldStartAdvertising else {
            return
        }
        
        // Add service and characteristics if needed
        if txCharacteristic == nil || rxCharacteristic == nil {
            
            let mutableTxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: AdvertiseData.txCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
            let mutableRxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: AdvertiseData.rxCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
            
            let service = CBMutableService(type: CBUUID(string: AdvertiseData.serviceUUID), primary: true)
            service.characteristics = [mutableTxCharacteristic, mutableRxCharacteristic];
            
            peripheralManager.add(service)
            
            self.txCharacteristic = mutableTxCharacteristic
            self.rxCharacteristic = mutableRxCharacteristic 
        }
        
        peripheralManager.startAdvertising(dataToBeAdvertised)
        
        shouldStartAdvertising = false;
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
        
        // Immediately set to connected if the tx Characteristic is already subscribed
        if txSubscribed {
            state = .connected
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("[BLE Peripheral] didAdd:", service, error ?? "success")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[BLE Peripheral] didReceiveRead:", request)
        
        // Only answer to requests if not idle
        guard state != .idle else {
            print("[BLE Peripheral] state = .idle -> not answering read request")
            return
        }
        
        // Not supported 
        peripheralManager.respond(to: request, withResult: .requestNotSupported)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[BLE Peripheral] didReceiveWrite:", requests)
        
        // Only answer to requests if not idle
        guard state != .idle else {
            print("[BLE Peripheral] state = .idle -> not answering write request")
            return
        }
        
        for request in requests {
            
            print("[BLE Peripheral] write request:", request);

            let characteristic = request.characteristic
            guard let data = request.value else {
              print("[BLE Peripheral] request.value is nil");
              return
            }

            // Write only supported in rxCharacteristic
            guard characteristic == self.rxCharacteristic else {
                peripheralManager.respond(to: request, withResult: .requestNotSupported)
                print("[BLE Peripheral] respond requestNotSupported (only supported in rxCharacteristic)")
                return 
            }

            print("[BLE Peripheral] request.value:", request.value)
            print("[BLE Peripheral] characteristic.value:", characteristic.value)
            
            if data.count > 0 {
                print("[BLE Peripheral] Receive data: \(data)")
                onDataReceived?(data)
            }
            
            // Respond with success
            peripheralManager.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        if characteristic == txCharacteristic {
            
            print("[BLE Peripheral] didSubscribeTo:", central, characteristic)
            
            // Update MTU
            self.mtu = central.maximumUpdateValueLength;

            // Add to subscriptions
            if #available(macOS 10.13, *) {
                txSubscriptions.insert(central.identifier)
            } else {
                // Fallback on earlier versions
            }
           
            txSubscribed = !txSubscriptions.isEmpty
            
            print("[BLE Peripheral] txSubscriptions:", txSubscriptions)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        
        if characteristic == txCharacteristic {
        
            print("[BLE Peripheral] didUnsubscribeFrom:", central, characteristic)
            
            // Remove from txSubscriptions
            if #available(macOS 10.13, *) {
                txSubscriptions.remove(central.identifier)
            } else {
                // Fallback on earlier versions
            }
            
            txSubscribed = !txSubscriptions.isEmpty
            
            print("[BLE Peripheral] txSubscriptions:", txSubscriptions)
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
