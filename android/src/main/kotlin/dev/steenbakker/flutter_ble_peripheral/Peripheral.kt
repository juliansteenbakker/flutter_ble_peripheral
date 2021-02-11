/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.*
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
    private val tag: String = "FlutterBlePeripheral"
    
    private val mAdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
            Log.i(tag, "LE Advertise Started.")
            //advertisingCallback(true)
            isAdvertising = true
        }
        
        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            Log.e(tag, "ERROR while starting advertising: $errorCode")
            val statusText: String

            when (errorCode) {
                ADVERTISE_FAILED_ALREADY_STARTED -> {
                    statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                    isAdvertising = true
                }
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                    statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    isAdvertising = false
                }
                ADVERTISE_FAILED_INTERNAL_ERROR -> {
                    statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                    isAdvertising = false
                }
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                    statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    isAdvertising = false
                }
                ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                    statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    isAdvertising = false
                }

                else -> {
                    statusText = "UNDOCUMENTED"
                }
            }

            Log.e(tag, "ERROR while starting advertising: $errorCode - $statusText")
            //advertisingCallback(false)
            isAdvertising = false
        }
    }
    
    fun init(context: Context) {
        if (mBluetoothLeAdvertiser == null) {
            mBluetoothLeAdvertiser = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter.bluetoothLeAdvertiser
        }
    }
    
    fun start(data: Data, settings: AdvertiseSettings) {
        val advertiseData = buildAdvertiseData(data)
        mBluetoothLeAdvertiser!!.startAdvertising(settings, advertiseData, mAdvertiseCallback)
    }

    fun isAdvertising(): Boolean {
        return isAdvertising
    }

    fun stop() {
        mBluetoothLeAdvertiser!!.stopAdvertising(mAdvertiseCallback)
        advertiseCallback = null
        isAdvertising = false
    }
    
    private fun buildAdvertiseData(data: Data): AdvertiseData? {
        /**
         * Note: There is a strict limit of 31 Bytes on packets sent over BLE Advertisements.
         * This includes everything put into AdvertiseData including UUIDs, device info, &
         * arbitrary service or manufacturer data.
         * Attempting to send packets over this limit will result in a failure with error code
         * AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE. Catch this error in the
         * onStartFailure() method of an AdvertiseCallback implementation.
         */
        val serviceData = data.serviceData?.let { intArrayToByteArray(it) }
        val manufacturerData = data.manufacturerData?.let { intArrayToByteArray(it) }
        val dataBuilder = AdvertiseData.Builder()
        dataBuilder.addServiceUuid(ParcelUuid.fromString(data.uuid))
        data.serviceDataUuid?.let { dataBuilder.addServiceData(ParcelUuid.fromString(it), serviceData) }
        data.manufacturerId?.let { dataBuilder.addManufacturerData(it, manufacturerData) }
        data.includeDeviceName?.let { dataBuilder.setIncludeDeviceName(it) }
        data.transmissionPowerIncluded?.let { dataBuilder.setIncludeTxPowerLevel(it) }
        return dataBuilder.build()
    }

    private fun intArrayToByteArray(ints: List<Int>): ByteArray {
        return ints.foldIndexed(ByteArray(ints.size)) { i, a, v -> a.apply { set(i, v.toByte()) } }
    }
}

