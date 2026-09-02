//
//  CentralState.swift
//  flutter_ble_central
//
//  Created by Julian Steenbakker on 12/04/2023.
//

import Foundation

/**
 Represents Bluetooth authorization and adapter state on iOS.

 This mirrors the Android `State` enum so the Flutter layer can work
 with a consistent set of values across platforms.

 - Note: Some states (e.g., `Restricted` and `Limited`) are only applicable on iOS.
 */
enum PeripheralBluetoothState: Int {

    /// The user granted access to the requested feature.
    case Granted = 0

    /// The user denied access, but the system may still prompt for permission.
    case Denied = 1

    /// Permission was permanently denied. The user must change it in Settings.
    case PermanentlyDenied = 2

    /// The app cannot request permission (e.g., parental controls or device restrictions).
    case Restricted = 3

    /// The user has authorized limited access (iOS 14+ only).
    case Limited = 4

    /// Bluetooth is turned off on the device.
    case TurnedOff = 5

    /// Bluetooth is unsupported on this device.
    case Unsupported = 6

    /// The status is unknown or could not be determined.
    case Unknown = 7

    /// Bluetooth is fully available and ready to use.
    case Ready = 8
}
