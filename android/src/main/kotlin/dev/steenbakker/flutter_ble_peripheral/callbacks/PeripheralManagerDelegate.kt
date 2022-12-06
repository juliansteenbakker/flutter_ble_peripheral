package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState


class PeripheralManagerDelegate(private val stateChangedHandler: StateChangedHandler? = null) : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent) {
        val action = intent.action
        if (BluetoothAdapter.ACTION_STATE_CHANGED == action) {
            when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)) {
                BluetoothAdapter.STATE_OFF -> {
                    stateChangedHandler?.publishPeripheralState(PeripheralState.poweredOff)
                }
                BluetoothAdapter.STATE_TURNING_ON -> {

                }
                BluetoothAdapter.STATE_ON -> {
                    stateChangedHandler?.publishPeripheralState(PeripheralState.idle)
                }
                BluetoothAdapter.STATE_TURNING_OFF -> {}
            }
        }
    }
}