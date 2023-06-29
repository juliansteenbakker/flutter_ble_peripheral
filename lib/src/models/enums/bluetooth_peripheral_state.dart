/*
 * Copyright (c) 2023. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:json_annotation/json_annotation.dart';

enum BluetoothPeripheralState {
  /// The user granted access to the requested feature.
  @JsonValue(0)
  granted,

  /// The user denied access to the requested feature, permission needs to be asked first.
  @JsonValue(1)
  denied,

  /// Permission to the requested feature is permanently denied,
  /// the permission dialog will not be shown when requesting this permission.
  /// The user may still change the permission status in the settings.
  @JsonValue(2)
  permanentlyDenied,

  /// The OS denied access to the requested feature.
  /// The user cannot change this app's status, possibly due to active restrictions such as parental controls being in place.
  ///
  /// Only supported on iOS.
  ///
  @JsonValue(3)
  restricted,

  /// User has authorized this application for limited access.
  /// Only supported on iOS (iOS14+).
  @JsonValue(4)
  limited,

  /// Bluetooth is turned off
  @JsonValue(5)
  turnedOff,
  @JsonValue(6)
  unsupported,

  /// The status is unknown
  @JsonValue(7)
  unknown,
  @JsonValue(8)
  ready,
}
