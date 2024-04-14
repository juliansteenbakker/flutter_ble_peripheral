//
//  PeripheralManagerDelegate.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import Foundation
import CoreBluetooth
import CoreLocation

extension FlutterBlePeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        stateHandler.baseState = peripheral.state
        stateHandler.publishPeripheralState()
        
        if peripheral.state == .poweredOff {
            stop()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("[flutter_ble_peripheral] didStartAdvertising:", error ?? "success")
        advertisingCallbacks.completeCallback(Unit.instance, error)
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        notificationManager.resume()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[flutter_ble_peripheral] didReceiveRead:", request)
        
        if let value = characteristics[request.characteristic.uuid]?.1 {
            onInteraction(request.central)
            
            if request.offset > value.count {
                peripheralManager.respond(to: request, withResult: .invalidOffset)
            } else {
                request.value = value.suffix(from: request.offset)
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[flutter_ble_peripheral] didReceiveWrite:", requests)
        
        for c in Set(requests.filter({ characteristics[$0.characteristic.uuid] != nil }).map({ $0.central })) {
            onInteraction(c)
        }
        
        for request in requests {
            print("[flutter_ble_peripheral] write request:", request);
            
            let characteristic = request.characteristic
            guard let data = request.value else {
                print("[flutter_ble_peripheral] request.value is nil");
                peripheral.respond(to: requests[0], withResult: .attributeNotLong)
                return
            }
            
            print("[flutter_ble_peripheral] Received data: \(data)")
            print("[flutter_ble_peripheral] Offset: \(request.offset)")
        }
        
        //TODO: write atomically if multiple requests are for the same characteristic
        for request in requests {
            write(characteristic: request.characteristic.uuid, data: request.value!, offset: request.offset)
        }
        
        peripheral.respond(to: requests[0], withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[flutter_ble_peripheral] didSubscribeTo:", central.identifier.uuidString, characteristic.uuid)
        
        onInteraction(central)
        subscriptionManager.subscribe(device: central, characteristic: characteristic.uuid)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[flutter_ble_peripheral] didUnsubscribeFrom:", central.identifier.uuidString, characteristic.uuid)
        
        subscriptionManager.unsubscribe(device: central, characteristic: characteristic.uuid)
        checkConnection(central)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("[flutter_ble_peripheral] didAdd:", service.uuid)
        addServiceCallbacks.completeCallback(service.uuid, error)
    }
}
