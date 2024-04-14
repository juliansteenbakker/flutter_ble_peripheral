package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.BluetoothDevice
import java.util.UUID

class BleFragmentManager {

    private val fragments : HashMap<BluetoothDevice,HashMap<UUID,ByteArray>> = HashMap()

    fun pushFragment(device : BluetoothDevice, uuid : UUID, value : ByteArray, offset : Int) {
        if (!fragments.containsKey(device)) {
            fragments[device] = HashMap()
        }
        val devData = fragments[device]!!

        if (!devData.containsKey(uuid)) {
            devData[uuid] = ByteArray(offset) + value
        } else if (offset < devData[uuid]!!.size) {
            value.copyInto(devData[uuid]!!, offset, 0, devData[uuid]!!.size - offset)
        } else {
            devData[uuid] = devData[uuid]!! + ByteArray(offset - devData[uuid]!!.size)
        }

        if (devData[uuid]!!.size < offset + value.size) {
            devData[uuid] = devData[uuid]!! + value.sliceArray(IntRange(devData[uuid]!!.size - offset, value.size))
        }
    }

    fun popData(device : BluetoothDevice) : HashMap<UUID, ByteArray> {
        val ans = fragments[device]!!
        fragments.remove(device)
        return ans
    }
}