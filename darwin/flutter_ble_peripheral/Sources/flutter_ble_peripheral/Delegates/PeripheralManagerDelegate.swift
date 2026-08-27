//
//  PeripheralManagerDelegate.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import Foundation
import CoreBluetooth

extension FlutterBlePeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        var state: PeripheralState
        switch peripheral.state {
        case .poweredOn:
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
        stateChangedHandler.publishPeripheralState(state: state)

        // After publishing idle, so the advertising state that this produces is
        // not overwritten by the state above.
        if peripheral.state == .poweredOn {
            startPendingAdvertisement()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        print("[flutter_ble_peripheral] didStartAdvertising:", error ?? "success")

        guard error == nil else {
            return
        }

        stateChangedHandler.publishPeripheralState(state: .advertising)

        // Immediately set to connected if the tx Characteristic is already subscribed
        if txSubscribed {
            stateChangedHandler.publishPeripheralState(state: .connected)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[flutter_ble_peripheral] didReceiveRead:", request)

        // Core Bluetooth only reports a central once it interacts, so a read is
        // also how a connection first becomes visible here.
        connectedCentrals.insert(request.central.identifier)

        guard let value = readValue(for: request.characteristic.uuid) else {
            peripheralManager.respond(to: request, withResult: .readNotPermitted)
            return
        }

        // A value longer than the MTU is fetched in pieces, each with a larger
        // offset, so only the tail is answered each time.
        guard request.offset <= value.count else {
            peripheralManager.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = value.subdata(in: request.offset..<value.count)
        peripheralManager.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[flutter_ble_peripheral] didReceiveWrite:", requests)

        for request in requests {
            print("[flutter_ble_peripheral] write request:", request)

            connectedCentrals.insert(request.central.identifier)

            let characteristic = request.characteristic
            guard let data = request.value else {
                print("[flutter_ble_peripheral] request.value is nil")
                peripheralManager.respond(to: request, withResult: .invalidAttributeValueLength)
                return
            }

            // Check if this is the RX characteristic (accept writes)
            if characteristic.uuid == rxCharacteristic?.uuid {
                print("[flutter_ble_peripheral] Received data on RX characteristic: \(data.count) bytes")

                if data.count > 0 {
                    // Publish received data to Flutter
                    dataReceivedHandler?.publishData(data: data)
                }

                // Respond with success
                peripheralManager.respond(to: request, withResult: .success)
            } else {
                // Write not supported on other characteristics
                print("[flutter_ble_peripheral] Write not supported on characteristic: \(characteristic.uuid)")
                peripheralManager.respond(to: request, withResult: .writeNotPermitted)
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[flutter_ble_peripheral] didSubscribeTo:", central.identifier, characteristic.uuid)

        if characteristic.uuid == txCharacteristic?.uuid {
            // Update MTU
            self.maximumNotificationSize = central.maximumUpdateValueLength
            print("[flutter_ble_peripheral] MTU updated: \(maximumNotificationSize + 3)")

            // Add to subscriptions and connected centrals
            txSubscriptions.insert(central.identifier)
            connectedCentrals.insert(central.identifier)

            txSubscribed = !txSubscriptions.isEmpty

            print("[flutter_ble_peripheral] txSubscriptions count: \(txSubscriptions.count)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[flutter_ble_peripheral] didUnsubscribeFrom:", central.identifier, characteristic.uuid)

        if characteristic.uuid == txCharacteristic?.uuid {
            // Remove from subscriptions and connected centrals
            txSubscriptions.remove(central.identifier)
            connectedCentrals.remove(central.identifier)

            txSubscribed = !txSubscriptions.isEmpty

            print("[flutter_ble_peripheral] txSubscriptions count: \(txSubscriptions.count)")

            // Update state based on remaining connections
            if !txSubscribed && peripheralManager.isAdvertising {
                stateChangedHandler.publishPeripheralState(state: .advertising)
            } else if !txSubscribed && !peripheralManager.isAdvertising {
                stateChangedHandler.publishPeripheralState(state: .idle)
            }
        }
    }

    /**
     Core Bluetooth is ready to take more notifications.

     `updateValue` drops a payload once the transmit queue is full, so anything
     that did not fit waits here rather than being lost.
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("[flutter_ble_peripheral] ready to update subscribers")
        drainNotifyQueue()
    }
}
