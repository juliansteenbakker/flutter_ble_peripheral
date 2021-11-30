//
//  PeripheralStatus.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 26/11/2021.
//

import Foundation

enum PeripheralState : Int{
//    case idle, unauthorized, unsupported, advertising, connected
    /// Status is not (yet) determined.
    case unknown

    /// BLE is not supported on this device.
    case unsupported

    /// BLE usage is not authorized for this app.
    case unauthorized

    /// BLE is turned off.
    case poweredOff

    // /// Android only: Location services are disabled.
    // locationServicesDisabled,

    /// BLE is fully operating for this app.
    case idle

    /// BLE is advertising data.
    case advertising

    /// BLE is connected to a device.
    case connected
    
//    var index: Int { PeripheralState..firstIndex(of: self) ?? 0 }
}


