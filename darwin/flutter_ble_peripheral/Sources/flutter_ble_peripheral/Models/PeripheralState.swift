//
//  PeripheralStatus.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 26/11/2021.
//

import Foundation

/**
 Represents the current state of the Flutter BLE Peripheral.

 This enum mirrors the BLE state used on the Flutter side,
 providing a unified model for cross-platform BLE peripheral state management.
 */
enum PeripheralState: Int {

    /// The current BLE status is not yet determined.
    case unknown

    /// BLE is not supported on this device.
    case unsupported

    /// The app is not authorized to use BLE.
    case unauthorized

    /// Bluetooth is currently turned off.
    case poweredOff
    
    /// Android only: Location services are disabled.
    case locationServicesDisabled

    /// BLE is available and ready to use, but not currently advertising or connected.
    case idle

    /// BLE is actively advertising data.
    case advertising

    /// BLE is connected to a remote device.
    case connected
}
