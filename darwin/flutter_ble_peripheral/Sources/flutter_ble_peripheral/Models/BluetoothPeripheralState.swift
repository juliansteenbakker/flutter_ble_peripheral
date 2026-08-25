/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Foundation

/// Mirrors the Dart `BluetoothPeripheralState`.
///
/// The raw value is that enum's index, which is what `start`, `stop` and the
/// permission methods return over the method channel. Keep the order in sync.
enum BluetoothPeripheralState: Int {
    case granted = 0
    case denied = 1
    case permanentlyDenied = 2
    case restricted = 3
    case limited = 4
    case turnedOff = 5
    case unsupported = 6
    case unknown = 7
    case ready = 8
}
