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
    }
}
