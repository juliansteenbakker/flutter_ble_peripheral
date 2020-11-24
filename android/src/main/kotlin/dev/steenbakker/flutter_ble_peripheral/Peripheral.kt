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
import android.widget.TextView
import io.flutter.Log
import java.util.*


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

    private val CHARACTERISTIC_USER_DESCRIPTION_UUID = UUID
            .fromString("00002901-0000-1000-8000-00805f9b34fb")
    private val CLIENT_CHARACTERISTIC_CONFIGURATION_UUID = UUID
            .fromString("00002902-0000-1000-8000-00805f9b34fb")

    private val mAdvStatus: TextView? = null
    private val mConnectionStatus: TextView? = null
    private val mBluetoothGattService: BluetoothGattService? = null
    private val mBluetoothDevices: HashSet<BluetoothDevice>? = null
    private val mBluetoothManager: BluetoothManager? = null
    private val mBluetoothAdapter: BluetoothAdapter? = null
    private val mAdvData: AdvertiseData? = null
    private val mAdvScanResponse: AdvertiseData? = null
    private val mAdvSettings: AdvertiseSettings? = null
    private val mAdvertiser: BluetoothLeAdvertiser? = null

    private val mGattServer: BluetoothGattServer? = null
    private val mGattServerCallback: BluetoothGattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                if (newState == BluetoothGatt.STATE_CONNECTED) {
                    mBluetoothDevices?.add(device)
                    Log.v(tag, "Connected to device: " + device.address)
                } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                    mBluetoothDevices?.remove(device)
                    Log.v(tag, "Disconnected from device")
                }
            } else {
                mBluetoothDevices?.remove(device)
                // There are too many gatt errors (some of them not even in the documentation) so we just
                // show the error to the user.
                Log.e(tag, "Error when connecting: $status")
            }
        }

        override fun onCharacteristicReadRequest(device: BluetoothDevice, requestId: Int, offset: Int,
                                                 characteristic: BluetoothGattCharacteristic) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
            Log.d(tag, "Device tried to read characteristic: " + characteristic.uuid)
            Log.d(tag, "Value: " + Arrays.toString(characteristic.value))
            if (offset != 0) {
                mGattServer!!.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset,  /* value (optional) */
                        null)
                return
            }
            mGattServer!!.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS,
                    offset, characteristic.value)
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            super.onNotificationSent(device, status)
            Log.v(tag, "Notification sent. Status: $status")
        }

        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int,
                                                  characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean,
                                                  offset: Int, value: ByteArray) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite,
                    responseNeeded, offset, value)
            Log.v(tag, "Characteristic Write request: " + Arrays.toString(value))

            // TODO: Fix write request
//            val status: Int = mCurrentServiceFragment.writeCharacteristic(characteristic, offset, value)
            if (responseNeeded) {
                mGattServer!!.sendResponse(device, requestId, 1,  /* No need to respond with an offset */
                        0,  /* No need to respond with a value */
                        null)
            }
        }

        override fun onDescriptorReadRequest(device: BluetoothDevice, requestId: Int,
                                             offset: Int, descriptor: BluetoothGattDescriptor) {
            super.onDescriptorReadRequest(device, requestId, offset, descriptor)
            Log.d(tag, "Device tried to read descriptor: " + descriptor.uuid)
            Log.d(tag, "Value: " + Arrays.toString(descriptor.value))
            if (offset != 0) {
                mGattServer!!.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset,  /* value (optional) */
                        null)
                return
            }
            mGattServer!!.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset,
                    descriptor.value)
        }

        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int,
                                              descriptor: BluetoothGattDescriptor, preparedWrite: Boolean, responseNeeded: Boolean,
                                              offset: Int,
                                              value: ByteArray) {
            super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded,
                    offset, value)
            Log.v(tag, "Descriptor Write Request " + descriptor.uuid + " " + Arrays.toString(value))
            var status = BluetoothGatt.GATT_SUCCESS
            if (descriptor.uuid === CLIENT_CHARACTERISTIC_CONFIGURATION_UUID) {
                val characteristic = descriptor.characteristic
                val supportsNotifications = characteristic.properties and
                        BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
                val supportsIndications = characteristic.properties and
                        BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
                if (!(supportsNotifications || supportsIndications)) {
                    status = BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED
                } else if (value.size != 2) {
                    status = BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH
                } else if (Arrays.equals(value, BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)) {
                    status = BluetoothGatt.GATT_SUCCESS
                    // TODO: Fix notifications
//                    mCurrentServiceFragment.notificationsDisabled(characteristic)
                    descriptor.value = value
                } else if (supportsNotifications &&
                        Arrays.equals(value, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                    status = BluetoothGatt.GATT_SUCCESS
                    // TODO: Fix notifications
//                    mCurrentServiceFragment.notificationsEnabled(characteristic, false /* indicate */)
                    descriptor.value = value
                } else if (supportsIndications &&
                        Arrays.equals(value, BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)) {
                    status = BluetoothGatt.GATT_SUCCESS
                    // TODO: Fix notifications
//                    mCurrentServiceFragment.notificationsEnabled(characteristic, true /* indicate */)
                    descriptor.value = value
                } else {
                    status = BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED
                }
            } else {
                status = BluetoothGatt.GATT_SUCCESS
                descriptor.value = value
            }
            if (responseNeeded) {
                mGattServer!!.sendResponse(device, requestId, status,  /* No need to respond with offset */
                        0,  /* No need to respond with a value */
                        null)
            }
        }
    }
    
    
    fun init(context: Context) {
        if (mBluetoothLeAdvertiser == null) {
            mBluetoothLeAdvertiser = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter.bluetoothLeAdvertiser
        }
    }
    
    fun start(data: Data) {
        val settings = buildAdvertiseSettings()
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

    /** TODO: make settings configurable */
    private fun buildAdvertiseSettings(): AdvertiseSettings? {
        val settingsBuilder = AdvertiseSettings.Builder()
        settingsBuilder.setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
        settingsBuilder.setTimeout(0)
        return settingsBuilder.build()
    }

    private fun intArrayToByteArray(ints: List<Int>): ByteArray {
        return ints.foldIndexed(ByteArray(ints.size)) { i, a, v -> a.apply { set(i, v.toByte()) } }
    }
}

