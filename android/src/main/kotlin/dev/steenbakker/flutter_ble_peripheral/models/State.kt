package dev.steenbakker.flutter_ble_peripheral.models

/*
 * Copyright (c) 2023. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

/// The ordinal of each entry is the value sent to Dart, where it indexes
/// BluetoothPeripheralState. Keep the order in sync with that enum.
enum class State {
    /// The user granted access to the requested feature.
    Granted,

    /// The user denied access to the requested feature, permission needs to be asked first.
    Denied,

    /// Permission to the requested feature is permanently denied,
    /// the permission dialog will not be shown when requesting this permission.
    /// The user may still change the permission status in the settings.
    PermanentlyDenied,

    /// The user cannot change this app's status, possibly due to active restrictions such as parental controls being in place.
    ///
    /// Only supported on iOS.
    Restricted,

    /// User has authorized this application for limited access.
    ///
    /// Only supported on iOS (iOS14+).
    Limited,

    /// Bluetooth is turned off.
    TurnedOff,

    /// Bluetooth is not supported on this device.
    Unsupported,

    /// The status is unknown.
    Unknown,

    /// Bluetooth is ready to be used.
    Ready,
}
