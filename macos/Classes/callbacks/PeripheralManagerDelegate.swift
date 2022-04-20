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
        var state: PeripheralState
        switch peripheral.state {
        case .poweredOn:
            state = .idle
//            addService() TODO: add service
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
        stateChangedHandler.publishPeripheralState(state: state)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("[flutter_ble_peripheral] didStartAdvertising:", error ?? "success")
        
        guard error == nil else {
            return
        }
        
        stateChangedHandler.publishPeripheralState(state: .advertising)
        
        // Immediately set to connected if the tx Characteristic is already subscribed
//        if txSubscribed {
//            state = .connected
//        }
    }
    
//    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
//        print("[flutter_ble_peripheral] didReceiveRead:", request)
//
//        // Only answer to requests if not idle
//        guard state != .idle else {
//            print("[flutter_ble_peripheral] state = .idle -> not answering read request")
//            return
//        }
//
//        // Not supported
//        peripheralManager.respond(to: request, withResult: .requestNotSupported)
//    }
//
//    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
//        print("[flutter_ble_peripheral] didReceiveWrite:", requests)
//
//        // Only answer to requests if not idle
//        guard state != .idle else {
//            print("[flutter_ble_peripheral] state = .idle -> not answering write request")
//            return
//        }
//
//        for request in requests {
//
//            print("[flutter_ble_peripheral] write request:", request);
//
//            let characteristic = request.characteristic
//            guard let data = request.value else {
//              print("[flutter_ble_peripheral] request.value is nil");
//              return
//            }
//
//            // Write only supported in rxCharacteristic
//            guard characteristic == self.rxCharacteristic else {
//                peripheralManager.respond(to: request, withResult: .requestNotSupported)
//                print("[flutter_ble_peripheral] respond requestNotSupported (only supported in rxCharacteristic)")
//                return
//            }
//
//            print("[flutter_ble_peripheral] request.value:", request.value!)
//            print("[flutter_ble_peripheral] characteristic.value:", characteristic.value!)
//
//            if data.count > 0 {
//                print("[flutter_ble_peripheral] Receive data: \(data)")
//                onDataReceived?(data)
//            }
//
//            // Respond with success
//            peripheralManager.respond(to: request, withResult: .success)
//        }
//    }
//
//    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
//
//        if characteristic == txCharacteristic {
//
//            print("[flutter_ble_peripheral] didSubscribeTo:", central, characteristic)
//
//            // Update MTU
//            self.mtu = central.maximumUpdateValueLength;
//
//            // Add to subscriptions
//            txSubscriptions.insert(central.identifier)
//
//            txSubscribed = !txSubscriptions.isEmpty
//
//            print("[flutter_ble_peripheral] txSubscriptions:", txSubscriptions)
//        }
//    }
//
//    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
//
//        if characteristic == txCharacteristic {
//
//            print("[flutter_ble_peripheral] didUnsubscribeFrom:", central, characteristic)
//
//            // Remove from txSubscriptions
//            txSubscriptions.remove(central.identifier)
//
//            txSubscribed = !txSubscriptions.isEmpty
//
//            print("[flutter_ble_peripheral] txSubscriptions:", txSubscriptions)
//        }
//    }
}
