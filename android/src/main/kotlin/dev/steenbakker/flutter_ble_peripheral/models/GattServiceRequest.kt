package dev.steenbakker.flutter_ble_peripheral.models

import android.bluetooth.BluetoothGattCharacteristic
import java.util.UUID

/**
 * One characteristic of the service Dart asked the peripheral to serve.
 *
 * [properties] is the bitmask this package defines in
 * `GattCharacteristicProperty`, not Android's own, so that the three platforms
 * decode the same numbers. It is translated to Android's properties and
 * permissions here.
 */
data class GattCharacteristicRequest(
    val uuid: UUID,
    val properties: Int,
) {
    val canNotify: Boolean
        get() = properties and (NOTIFY or INDICATE) != 0

    val canWrite: Boolean
        get() = properties and (WRITE or WRITE_WITHOUT_RESPONSE) != 0

    /** The Android properties matching [properties]. */
    val androidProperties: Int
        get() {
            var value = 0
            if (properties and READ != 0) value = value or BluetoothGattCharacteristic.PROPERTY_READ
            if (properties and WRITE != 0) value = value or BluetoothGattCharacteristic.PROPERTY_WRITE
            if (properties and WRITE_WITHOUT_RESPONSE != 0) {
                value = value or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE
            }
            if (properties and NOTIFY != 0) value = value or BluetoothGattCharacteristic.PROPERTY_NOTIFY
            if (properties and INDICATE != 0) value = value or BluetoothGattCharacteristic.PROPERTY_INDICATE
            return value
        }

    /**
     * The Android permissions matching [properties].
     *
     * A characteristic that can be notified is also readable, so that a central
     * which subscribes late can still pick up the payload sent last.
     */
    val androidPermissions: Int
        get() {
            var value = 0
            if (properties and READ != 0 || canNotify) {
                value = value or BluetoothGattCharacteristic.PERMISSION_READ
            }
            if (canWrite) value = value or BluetoothGattCharacteristic.PERMISSION_WRITE
            return value
        }

    companion object {
        const val READ = 1
        const val WRITE = 2
        const val WRITE_WITHOUT_RESPONSE = 4
        const val NOTIFY = 8
        const val INDICATE = 16
    }
}

/**
 * The GATT service Dart asked the peripheral to serve, with the characteristics
 * it chose.
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
    val characteristics: List<GattCharacteristicRequest>,
) {
    /** The characteristics `sendData` can deliver on. */
    val notifying: List<GattCharacteristicRequest>
        get() = characteristics.filter { it.canNotify }
}

/** What came of a `sendData` call, so the plugin can answer Dart precisely. */
enum class SendResult {
    /** Queued for at least one subscribed central. */
    Sent,

    /** No GATT server is running, or it serves nothing that notifies. */
    NoServer,

    /** The named characteristic is not one this service notifies on. */
    UnknownCharacteristic,

    /** No characteristic was named, and the service notifies on several. */
    AmbiguousCharacteristic,

    /** Nobody is subscribed to the characteristic, so nothing can be sent. */
    NotSubscribed,
}
