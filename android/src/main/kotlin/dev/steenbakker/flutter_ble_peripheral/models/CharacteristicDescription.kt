package dev.steenbakker.flutter_ble_peripheral.models

import android.bluetooth.BluetoothGattCharacteristic
import java.util.UUID

class CharacteristicDescription(
    uuid: String,
    val value: ByteArray,
    val read: Boolean,
    val write: Boolean,
    val writeNR: Boolean,
    val notify: Boolean,
    val indicate: Boolean,
) {
    val uuid = UUID.fromString(uuid)

    constructor(properties: Map<String, Any>) : this(
        properties["uuid"] as String,
        properties["value"] as ByteArray,
        properties["read"] as Boolean,
        properties["write"] as Boolean,
        properties["writeNR"] as Boolean,
        properties["notify"] as Boolean,
        properties["indicate"] as Boolean
    )

    fun properties() : Int {
        var ans: Int = 0
        if (read) ans = ans or BluetoothGattCharacteristic.PROPERTY_READ
        if (write) ans = ans or BluetoothGattCharacteristic.PROPERTY_WRITE
        if (writeNR) ans = ans or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE
        if (notify) ans = ans or BluetoothGattCharacteristic.PROPERTY_NOTIFY
        if (indicate) ans = ans or BluetoothGattCharacteristic.PROPERTY_INDICATE
        return ans
    }

    fun permissions() : Int {
        var ans: Int = 0
        if (read) ans = ans or BluetoothGattCharacteristic.PERMISSION_READ
        if (write || writeNR) ans = ans or BluetoothGattCharacteristic.PERMISSION_WRITE
        return ans
    }
}