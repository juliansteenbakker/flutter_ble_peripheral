/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */


import Foundation
import CoreBluetooth
import CoreLocation

class FlutterBlePeripheralManager : NSObject {
    
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
          onMtuChanged?(mtu)
        }
    }
    
    var onStateChanged: ((PeripheralState) -> Void)?
    var onMtuChanged: ((Int) -> Void)?
    var onDataReceived: ((Data) -> Void)?
    
    var dataToBeAdvertised: [String: Any]!
    
//    var shouldStartAdvertising = false
    
    var txCharacteristic: CBMutableCharacteristic?
    var txSubscribed = false {
        didSet {
            if txSubscribed {
                state = .connected
            } else if isAdvertising() {
                state = .advertising
            }
        }
    }
    var rxCharacteristic: CBMutableCharacteristic?
    
    var txSubscriptions = Set<UUID>()
    
    func start(advertiseData: PeripheralData) {
        
        dataToBeAdvertised = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = [advertiseData.localName]
        }
        
        peripheralManager.startAdvertising(dataToBeAdvertised)
        
//        shouldStartAdvertising = true
        
        // TODO: add service when bool is set
//        if peripheralManager.state == .poweredOn {
//            addService()
//        }
    }
    
    func stop() {
    
//        shouldStartAdvertising = false
        
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
        
//        guard shouldStartAdvertising else {
//            return
//        }
        
        // Add service and characteristics if needed
        if txCharacteristic == nil || rxCharacteristic == nil {
            
            let mutableTxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: PeripheralData.txCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
            let mutableRxCharacteristic = CBMutableCharacteristic(type: CBUUID(string: PeripheralData.rxCharacteristicUUID), properties: [.read, .write, .notify], value: nil, permissions: [.readable, .writeable])
            
            let service = CBMutableService(type: CBUUID(string: PeripheralData.serviceUUID), primary: true)
            service.characteristics = [mutableTxCharacteristic, mutableRxCharacteristic];
            
            peripheralManager.add(service)
            
            self.txCharacteristic = mutableTxCharacteristic
            self.rxCharacteristic = mutableRxCharacteristic 
        }
        
        peripheralManager.startAdvertising(dataToBeAdvertised)
        
//        shouldStartAdvertising = false;
    }
    
    func send(data: Data) {
        
        print("[flutter_ble_peripheral] Send data: \(data)")
        
        guard let characteristic = txCharacteristic else { 
            return
        }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
}

extension FlutterBlePeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
//            addService() TODO: add service
            state = .idle
        case .poweredOff:
            state = .poweredOff
        case .resetting:
            state = .idle
        case .unsupported:
            state = .unsupported
        case .unauthorized:
            state = .unauthorized
        case .unknown:
            state = .unknown
        @unknown default:
            state = .unknown
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("[flutter_ble_peripheral] didStartAdvertising:", error ?? "success")
        
        guard error == nil else {
            return
        }
        
        state = .advertising
        
        // Immediately set to connected if the tx Characteristic is already subscribed
        if txSubscribed {
            state = .connected
        }
    }
    
//    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
//        print("[flutter_ble_peripheral] didAdd:", service, error ?? "success")
//    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[flutter_ble_peripheral] didReceiveRead:", request)
        
        // Only answer to requests if not idle
        guard state != .idle else {
            print("[flutter_ble_peripheral] state = .idle -> not answering read request")
            return
        }
        
        // Not supported 
        peripheralManager.respond(to: request, withResult: .requestNotSupported)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[flutter_ble_peripheral] didReceiveWrite:", requests)
        
        // Only answer to requests if not idle
        guard state != .idle else {
            print("[flutter_ble_peripheral] state = .idle -> not answering write request")
            return
        }
        
        for request in requests {
            
            print("[flutter_ble_peripheral] write request:", request);

            let characteristic = request.characteristic
            guard let data = request.value else {
              print("[flutter_ble_peripheral] request.value is nil");
              return
            }

            // Write only supported in rxCharacteristic
            guard characteristic == self.rxCharacteristic else {
                peripheralManager.respond(to: request, withResult: .requestNotSupported)
                print("[flutter_ble_peripheral] respond requestNotSupported (only supported in rxCharacteristic)")
                return 
            }

            print("[flutter_ble_peripheral] request.value:", request.value)
            print("[flutter_ble_peripheral] characteristic.value:", characteristic.value)
            
            if data.count > 0 {
                print("[flutter_ble_peripheral] Receive data: \(data)")
                onDataReceived?(data)
            }
            
            // Respond with success
            peripheralManager.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        if characteristic == txCharacteristic {
            
            print("[flutter_ble_peripheral] didSubscribeTo:", central, characteristic)
            
            // Update MTU
            self.mtu = central.maximumUpdateValueLength;

            // Add to subscriptions
            txSubscriptions.insert(central.identifier)
           
            txSubscribed = !txSubscriptions.isEmpty
            
            print("[flutter_ble_peripheral] txSubscriptions:", txSubscriptions)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        
        if characteristic == txCharacteristic {
        
            print("[flutter_ble_peripheral] didUnsubscribeFrom:", central, characteristic)
            
            // Remove from txSubscriptions
            txSubscriptions.remove(central.identifier)
            
            txSubscribed = !txSubscriptions.isEmpty
            
            print("[flutter_ble_peripheral] txSubscriptions:", txSubscriptions)
        }
    }
}


