/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Foundation

/**
 The GATT service Dart asked the peripheral to serve, with the characteristic
 uuids it chose.

 The uuids are always supplied by Dart rather than derived from the service
 uuid, so that they stay the same across app launches and platforms. Deriving
 them from a Swift `hashValue` would change them on every launch, because that
 hash is seeded per process.
 */
struct GattServiceRequest {
    let serviceUuid: String
    let txCharacteristicUuid: String
    let rxCharacteristicUuid: String

    /// Reads the request out of the `start` arguments, or nil when Dart asked
    /// to advertise without a service.
    static func from(_ map: [String: Any]?) throws -> GattServiceRequest? {
        guard let serviceUuid = map?["gattServiceUuid"] as? String else { return nil }
        guard let txUuid = map?["gattTxCharacteristicUuid"] as? String,
              let rxUuid = map?["gattRxCharacteristicUuid"] as? String else {
            throw FlutterBlePeripheralError.invalidServiceUuid(serviceUuid)
        }
        return GattServiceRequest(
            serviceUuid: serviceUuid,
            txCharacteristicUuid: txUuid,
            rxCharacteristicUuid: rxUuid
        )
    }
}
