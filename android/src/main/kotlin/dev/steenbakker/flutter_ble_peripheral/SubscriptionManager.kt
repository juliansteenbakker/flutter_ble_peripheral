package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattDescriptor
import java.util.UUID

class SubscriptionManager {
    private val subscriptions: HashMap<BluetoothDevice,HashMap<UUID,Boolean>> = HashMap()

    fun subscribe(device : BluetoothDevice, characteristic : UUID, confirm : Boolean) {
        if (!subscriptions.containsKey(device)) {
            subscriptions[device] = HashMap()
        }

        subscriptions[device]!![characteristic] = confirm
    }

    fun unsubscribe(device: BluetoothDevice, characteristic: UUID) {
        subscriptions[device]!!.remove(characteristic)
    }

    fun removeDeviceData(device: BluetoothDevice) {
        subscriptions.remove(device)
    }

    fun removeCharacteristicData(uuid: UUID) {
        for ((_, sub) in subscriptions) {
            sub.remove(uuid)
        }
    }

    fun subscriptions(characteristic: UUID) : Sequence<Pair<BluetoothDevice,Boolean>> {
        return sequence {
            for ((device, sub) in subscriptions) {
                if (sub.containsKey(characteristic)) {
                    yield(Pair(device, sub[characteristic]!!))
                }
            }
        }
    }

    fun getRawValue(device: BluetoothDevice, characteristic: UUID) : ByteArray {
        if (!subscriptions.containsKey(device) || !subscriptions[device]!!.containsKey(characteristic))
            return BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE

        return if (subscriptions[device]!![characteristic]!!)
            BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        else
            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
    }
}