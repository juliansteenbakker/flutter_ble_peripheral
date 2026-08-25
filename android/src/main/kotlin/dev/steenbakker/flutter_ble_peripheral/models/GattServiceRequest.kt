package dev.steenbakker.flutter_ble_peripheral.models

/**
 * The GATT service Dart asked the peripheral to serve, with the characteristic
 * uuids it chose.
 *
 * The uuids are always supplied by Dart rather than derived from the service
 * uuid, so that they stay the same across app launches and platforms. A central
 * caches the GATT database between connections, so a characteristic uuid that
 * moves breaks the link.
 */
data class GattServiceRequest(
    val serviceUuid: String,
    val txCharacteristicUuid: String,
    val rxCharacteristicUuid: String,
)
