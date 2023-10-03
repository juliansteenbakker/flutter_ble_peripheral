package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.BluetoothDevice
import java.util.UUID

class BleFragmentManager {

    private val fragments : HashMap<BluetoothDevice,HashMap<UUID,ByteArray>> = HashMap()

    fun pushFragment(device : BluetoothDevice, uuid : UUID, value : ByteArray) {
        if (!fragments.containsKey(device)) {
            fragments[device] = HashMap()
        }

        val aux = fragments[device]!!

        if (!aux.containsKey(uuid)) {
            aux[uuid] = value
        } else {
            aux[uuid] = aux[uuid]!! + value
        }
    }

    fun popData(device : BluetoothDevice) : HashMap<UUID, ByteArray> {
        val ans = fragments[device]!!
        fragments.remove(device)
        return ans
    }
}