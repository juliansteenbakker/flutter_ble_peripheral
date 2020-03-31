/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import io.flutter.Log

class Peripheral {

    private var isAdvertising = false
    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private val tag = "FlutterBlePeripheral"

    fun init(context: Context) {
        if (mBluetoothLeAdvertiser == null) {
            val mBluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
            if (mBluetoothManager != null) {
                val mBluetoothAdapter = mBluetoothManager.adapter
                if (mBluetoothAdapter != null) {
                    mBluetoothLeAdvertiser = mBluetoothAdapter.bluetoothLeAdvertiser
                }
            }
        }
    }

    fun start(data: Data, advertisingCallback: ((Boolean) -> Unit)) {
        val settings = buildAdvertiseSettings()
        val advertiseData = buildAdvertiseData(data.uuid, false)

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                Log.d(tag, "Started advertising")
                advertisingCallback(true)
                isAdvertising = true
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                Log.d(tag, "ERROR advertising: $errorCode")
                advertisingCallback(false)
                isAdvertising = false
            }
        }

        mBluetoothLeAdvertiser?.startAdvertising(settings, advertiseData, advertiseCallback)
    }

    fun isAdvertising(): Boolean {
        return isAdvertising
    }

//    fun isTransmissionSupported(): Int {
//        return checkTransmissionSupported(context)
//    }

    fun stop() {
        Log.d(tag, "Stopped advertising")
        mBluetoothLeAdvertiser!!.stopAdvertising(advertiseCallback)
        advertiseCallback = null
        isAdvertising = false
    }

    /** TODO: Expand advertising data */
    private fun buildAdvertiseData(uuid: String, includeDeviceName: Boolean): AdvertiseData? {
        /**
         * Note: There is a strict limit of 31 Bytes on packets sent over BLE Advertisements.
         * This includes everything put into AdvertiseData including UUIDs, device info, &
         * arbitrary service or manufacturer data.
         * Attempting to send packets over this limit will result in a failure with error code
         * AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE. Catch this error in the
         * onStartFailure() method of an AdvertiseCallback implementation.
         */
        val dataBuilder = AdvertiseData.Builder()
        dataBuilder.addServiceUuid(ParcelUuid.fromString(uuid))
        dataBuilder.setIncludeDeviceName(includeDeviceName)

        return dataBuilder.build()
    }

    /** TODO: make settings configurable */
    private fun buildAdvertiseSettings(): AdvertiseSettings? {
        val settingsBuilder = AdvertiseSettings.Builder()
        settingsBuilder.setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
        settingsBuilder.setTimeout(0)
        return settingsBuilder.build()
    }
}