/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Foundation
import CoreBluetooth

/**
 One characteristic of the service Dart asked the peripheral to serve.

 `properties` is the bitmask this package defines in
 `GattCharacteristicProperty`, not Core Bluetooth's own, so that the three
 platforms decode the same numbers. It is translated to Core Bluetooth's
 properties and permissions here.
 */
struct GattCharacteristicRequest {
    static let read = 1
    static let write = 2
    static let writeWithoutResponse = 4
    static let notify = 8
    static let indicate = 16

    let uuid: CBUUID
    let properties: Int

    var canNotify: Bool {
        properties & (GattCharacteristicRequest.notify | GattCharacteristicRequest.indicate) != 0
    }

    var canWrite: Bool {
        properties
            & (GattCharacteristicRequest.write | GattCharacteristicRequest.writeWithoutResponse) != 0
    }

    /// The Core Bluetooth properties matching `properties`.
    var coreProperties: CBCharacteristicProperties {
        var value: CBCharacteristicProperties = []
        if properties & GattCharacteristicRequest.read != 0 { value.insert(.read) }
        if properties & GattCharacteristicRequest.write != 0 { value.insert(.write) }
        if properties & GattCharacteristicRequest.writeWithoutResponse != 0 {
            value.insert(.writeWithoutResponse)
        }
        if properties & GattCharacteristicRequest.notify != 0 { value.insert(.notify) }
        if properties & GattCharacteristicRequest.indicate != 0 { value.insert(.indicate) }
        return value
    }

    /**
     The Core Bluetooth permissions matching `properties`.

     A characteristic that can be notified is readable as well, so that a
     central which subscribes late can still pick up the payload sent last.
     */
    var corePermissions: CBAttributePermissions {
        var value: CBAttributePermissions = []
        if properties & GattCharacteristicRequest.read != 0 || canNotify {
            value.insert(.readable)
        }
        if canWrite { value.insert(.writeable) }
        return value
    }

    /// Reads one characteristic out of the map Dart sent.
    static func from(_ map: [String: Any]) throws -> GattCharacteristicRequest {
        guard let uuid = map["uuid"] as? String else {
            throw FlutterBlePeripheralError.invalidServiceUuid("<missing>")
        }
        return GattCharacteristicRequest(
            uuid: try FlutterBlePeripheralManager.requireServiceUuid(uuid),
            properties: map["properties"] as? Int ?? 0
        )
    }
}

/**
 The GATT service Dart asked the peripheral to serve, with the characteristics
 it chose.

 The uuids are always supplied by Dart rather than derived from the service
 uuid, so that they stay the same across app launches and platforms. A central
 caches the GATT database between connections, so a characteristic uuid that
 moves breaks the link.

 They are parsed as they come off the channel, since `CBUUID(string:)` raises an
 Objective-C exception that cannot be caught from Swift on anything it does not
 recognise, and a failure has to reach Dart rather than take the app down.
 */
struct GattServiceRequest {
    let serviceUuid: CBUUID
    let characteristics: [GattCharacteristicRequest]

    /// The characteristics `sendData` can deliver on.
    var notifying: [GattCharacteristicRequest] {
        characteristics.filter(\.canNotify)
    }

    /// Reads the request out of the `start` arguments, or nil when Dart asked
    /// to advertise without a service.
    static func from(_ map: [String: Any]?) throws -> GattServiceRequest? {
        guard let serviceUuid = map?["gattServiceUuid"] as? String else { return nil }
        guard let entries = map?["gattCharacteristics"] as? [[String: Any]], !entries.isEmpty else {
            throw FlutterBlePeripheralError.invalidServiceUuid(serviceUuid)
        }
        return GattServiceRequest(
            serviceUuid: try FlutterBlePeripheralManager.requireServiceUuid(serviceUuid),
            characteristics: try entries.map { try GattCharacteristicRequest.from($0) }
        )
    }
}

/// What came of a `sendData` call, so the plugin can answer Dart precisely.
enum SendResult {
    /// Queued for at least one subscribed central.
    case sent

    /// No GATT server is running, or it serves nothing that notifies.
    case noServer

    /// The named characteristic is not one this service notifies on.
    case unknownCharacteristic

    /// No characteristic was named, and the service notifies on several.
    case ambiguousCharacteristic

    /// Nobody is subscribed to the characteristic, so nothing can be sent.
    case notSubscribed
}
