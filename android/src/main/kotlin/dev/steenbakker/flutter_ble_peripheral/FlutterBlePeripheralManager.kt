/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.plugin.common.MethodChannel


class FlutterBlePeripheralManager(private val stateHandler : StateChangedHandler, context: Context) {

    companion object {
        const val TAG: String = "FlutterBlePeripheralManager"
    }

    private var mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null

    private var advertisingSetCallback: PeripheralAdvertisingSetCallback? = null
    private var advertiseCallback: PeripheralAdvertisingCallback? = null

    fun isEnabled() : Boolean {
        if (mBluetoothManager == null) throw PeripheralException(PeripheralState.unsupported)
        return mBluetoothManager!!.adapter.isEnabled
    }

    fun enableBluetooth(result: MethodChannel.Result) {
        if (mBluetoothManager == null) throw PeripheralException(PeripheralState.unsupported)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(mBluetoothManager!!.adapter.enable())
        } else {
            result.error("Deprecated operation", "Enabling bluetooth automatically is deprecated from API33 onwards", null)
        }
    }

    private fun checkBluetoothState() {
        if (mBluetoothManager == null) throw PeripheralException(PeripheralState.unsupported)

        // Can't check whether ble is turned off or not supported, see https://stackoverflow.com/questions/32092902/why-ismultipleadvertisementsupported-returns-false-when-getbluetoothleadverti
        // !bluetoothAdapter.isMultipleAdvertisementSupported
        mBluetoothLeAdvertiser = mBluetoothManager!!.adapter.bluetoothLeAdvertiser
                ?: throw PeripheralException(PeripheralState.poweredOff)
    }

    /**
     * Start advertising using the startAdvertising() method.
     */
    fun start(peripheralData: AdvertiseData, peripheralSettings: AdvertiseSettings, peripheralResponse: AdvertiseData?, result : MethodChannel.Result) {

        checkBluetoothState()
        advertiseCallback = PeripheralAdvertisingCallback(result, stateHandler, peripheralSettings.timeout.toLong())

        mBluetoothLeAdvertiser!!.startAdvertising(
                peripheralSettings,
                peripheralData,
                peripheralResponse,
                advertiseCallback,
        )
    }

    /**
     * Start advertising using the startAdvertisingSet method.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(advertiseData: AdvertiseData, advertiseSettingsSet: AdvertisingSetParameters, peripheralResponse: AdvertiseData?,
                 periodicResponse: AdvertiseData?, periodicResponseSettings: PeriodicAdvertisingParameters?, maxExtendedAdvertisingEvents: Int = 0, duration: Int = 0, result : MethodChannel.Result) {

        checkBluetoothState()
        advertisingSetCallback = PeripheralAdvertisingSetCallback(result, stateHandler)

        mBluetoothLeAdvertiser!!.startAdvertisingSet(
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

    fun stop(result: MethodChannel.Result? = null) {
        checkBluetoothState()

        if (advertisingSetCallback != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mBluetoothLeAdvertiser!!.stopAdvertisingSet(advertisingSetCallback!!)
            advertisingSetCallback = null
        } else {
            mBluetoothLeAdvertiser!!.stopAdvertising(advertiseCallback!!)
            advertiseCallback!!.dispose()
            advertiseCallback = null
        }

        result?.success(null)
    }
}