/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

enum PeripheralState {
  /// Status is not (yet) determined.
  unknown,

  /// BLE is not supported on this device.
  unsupported,

  /// BLE usage is not authorized for this app.
  unauthorized,

  /// BLE is turned off.
  poweredOff,

  /// BLE is fully operating for this app.
  idle,

  /// BLE is advertising data.
  advertising,

  /// BLE is connected to a device.
  connected,
}

extension PeripheralStateExtension on PeripheralState {
  int get code {
    switch (this) {
      case PeripheralState.unknown:
        return 10;
      case PeripheralState.unsupported:
        return 11;
      case PeripheralState.unauthorized:
        return 12;
      case PeripheralState.poweredOff:
        return 13;
      case PeripheralState.idle:
        return 14;
      case PeripheralState.advertising:
        return 15;
      case PeripheralState.connected:
        return 16;
    }
  }
}
