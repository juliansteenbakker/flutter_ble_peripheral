/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Foundation

/// A bad argument from Dart, reported back over the method channel as a
/// PlatformException rather than crashing the process.
enum FlutterBlePeripheralError: Error {
    case invalidServiceUuid(String)

    var code: String {
        switch self {
        case .invalidServiceUuid:
            return "invalidServiceUuid"
        }
    }

    var message: String {
        switch self {
        case .invalidServiceUuid(let value):
            return "Invalid service uuid: \(value). Expected a 16 bit (\"A1B2\"), 32 bit (\"A1B2C3D4\") or 128 bit uuid."
        }
    }
}
