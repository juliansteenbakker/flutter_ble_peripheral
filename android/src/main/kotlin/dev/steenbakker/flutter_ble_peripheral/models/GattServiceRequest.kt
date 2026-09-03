package dev.steenbakker.flutter_ble_peripheral.models

import java.util.UUID

/**
 * The GATT service Dart asked the peripheral to serve, with the characteristic
 * uuids it chose.
 *
 * The uuids are always supplied by Dart rather than derived from the service
 * uuid, so that they stay the same across app launches and platforms. A central
 * caches the GATT database between connections, so a characteristic uuid that
 * moves breaks the link.
 *
 * They are parsed as they come off the channel, so a short form Dart sent is
 * already expanded onto the Bluetooth Base UUID here, and everything downstream
 * compares one canonical form against what Android reports on air.
 */
data class GattServiceRequest(
    val serviceUuid: UUID,
    val txCharacteristicUuid: UUID,
    val rxCharacteristicUuid: UUID,
)
