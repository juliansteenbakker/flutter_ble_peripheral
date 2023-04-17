package dev.steenbakker.flutter_ble_peripheral.models

/*
 * Copyright (c) 2023. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

enum class State(val value: Int) {
    /// The user granted access to the requested feature.
    Granted(1),  /// The user denied access to the requested feature, permission needs to be asked first.
    Denied(2),  /// Permission to the requested feature is permanently denied,

    /// the permission dialog will not be shown when requesting this permission.
    /// The user may still change the permission status in the settings.
    PermanentlyDenied(3),  /// The status is unknown


    /// The user cannot change this app's status, possibly due to active restrictions such as parental controls being in place.
    ///
    /// Only supported on iOS.
    Restricted(4),  /// User has authorized this application for limited access.

    /// Only supported on iOS (iOS14+).
    Limited(5),  /// Bluetooth is turned off
    TurnedOff(6),
    Unsupported(7),
    Unknown(8),
    Ready(9),
}