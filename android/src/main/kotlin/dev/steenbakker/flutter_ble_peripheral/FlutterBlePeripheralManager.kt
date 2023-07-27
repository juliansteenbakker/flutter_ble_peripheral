/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.RequiresApi
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.plugin.common.MethodChannel

//TODO: BUG FIX
// Call startAdvertising with 20 seconds of advertising, then stopAdvertising, then startAdvertising again before the 20 seconds pass.
// Expected behaviour would be for the new advertising to last for another 20 seconds.
// However, it stops when the original 20 seconds are up (tested in API30. in API33 seems to work properly)
// I'm not sure whether the currently implemented Timer logic should reflect this behaviour, since it is most likely a bug in the underlying BLE API

class FlutterBlePeripheralManager(private val stateHandler : StateChangedHandler, context: Context) : BroadcastReceiver() {
    companion object {
        const val TAG: String = "FlutterBlePeripheralManager"
    }

    private val _mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val mBluetoothManager: BluetoothManager get() {
        return _mBluetoothManager ?: throw PeripheralException(PeripheralState.unsupported)
    }

    private var _mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private val mBluetoothLeAdvertiser: BluetoothLeAdvertiser get() {
        // Can't check whether ble is turned off or not supported, see https://stackoverflow.com/questions/32092902/why-ismultipleadvertisementsupported-returns-false-when-getbluetoothleadverti
        // !bluetoothAdapter.isMultipleAdvertisementSupported
        _mBluetoothLeAdvertiser = mBluetoothManager.adapter.bluetoothLeAdvertiser
            ?: throw PeripheralException(PeripheralState.poweredOff)

        return _mBluetoothLeAdvertiser!!
    }

    private var advertisingSetCallback: PeripheralAdvertisingSetCallback? = null
    private var advertiseCallback: PeripheralAdvertisingCallback? = null

    override fun onReceive(context: Context?, intent: Intent) {
        val action = intent.action

        if (action == BluetoothAdapter.ACTION_STATE_CHANGED) {
            //if (btAdapter.getState() == BluetoothAdapter.STATE_TURNING_OFF) {
            //    // The user bluetooth is turning off yet, but it is not disabled yet.
            //    TODO?
            //}
            stateHandler.publishPeripheralState()
            if (!stateHandler.bluetoothPowered) {
                //turning off bluetooth automatically stops all advertising
                advertiseCallback?.dispose()
                advertiseCallback = null
                advertisingSetCallback = null
            }
        }
    }

    /**
     * Automatically enable bluetooth (without asking for user's consent)
     * Only available before API 33
     */
    fun enableBluetooth(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(mBluetoothManager.adapter.enable())
            stateHandler.publishPeripheralState()
        } else {
            result.error("UnsupportedOperation", "Enabling bluetooth automatically is deprecated from API33 onwards", null)
        }
    }

    /**
     * Start advertising using the startAdvertising() method.
     */
    fun start(peripheralData: AdvertiseData, peripheralSettings: AdvertiseSettings, peripheralResponse: AdvertiseData?, result : MethodChannel.Result) {

        advertiseCallback = PeripheralAdvertisingCallback(result, stateHandler, peripheralSettings.timeout.toLong())

        mBluetoothLeAdvertiser.startAdvertising(
                peripheralSettings,
                peripheralData,
                peripheralResponse,
                advertiseCallback,
        )
    }

    /**
     * Start advertising using the startAdvertisingSet() method.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(advertiseData: AdvertiseData, advertiseSettingsSet: AdvertisingSetParameters, peripheralResponse: AdvertiseData?,
                 periodicResponse: AdvertiseData?, periodicResponseSettings: PeriodicAdvertisingParameters?, maxExtendedAdvertisingEvents: Int = 0, duration: Int = 0, result : MethodChannel.Result) {

        advertisingSetCallback = PeripheralAdvertisingSetCallback(result, stateHandler)

        mBluetoothLeAdvertiser.startAdvertisingSet(
                advertiseSettingsSet,
                advertiseData,
                peripheralResponse,
                periodicResponseSettings,
                periodicResponse,
                duration,
                maxExtendedAdvertisingEvents,
                advertisingSetCallback
        )
    }

    /**
     * Stop advertising
     * Since only one advertising is active at a time, this method effectively stops all advertising
     */
    fun stop(result: MethodChannel.Result? = null) {
        if (advertisingSetCallback != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mBluetoothLeAdvertiser.stopAdvertisingSet(advertisingSetCallback!!)
            advertisingSetCallback = null
        } else if (advertiseCallback != null) {
            mBluetoothLeAdvertiser.stopAdvertising(advertiseCallback!!)
            advertiseCallback!!.dispose()
            advertiseCallback = null
        }

        result?.success(null)
    }
}