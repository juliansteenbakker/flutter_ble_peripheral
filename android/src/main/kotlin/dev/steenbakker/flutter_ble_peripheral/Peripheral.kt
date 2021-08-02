/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid
import io.flutter.Log
import java.util.*

enum class PeripheralState {
    idle, unauthorized, unsupported, advertising, connected
}

class Peripheral {
    private val tag: String = "FlutterBlePeripheral"
    private lateinit var mBluetoothManager: BluetoothManager
    private lateinit var mBluetoothLeAdvertiser: BluetoothLeAdvertiser
    private lateinit var mBluetoothGattServer: BluetoothGattServer
    private var mBluetoothDevice: BluetoothDevice? = null

    private lateinit var context: Context


    private var isAdvertising = false
    private var advertiseCallback: ((Boolean) -> Unit)? = null

    private var shouldAdvertise = false

    private var state = PeripheralState.idle
    var onStateChanged: ((PeripheralState) -> Unit)? = null
    private fun updateState(newState: PeripheralState) {
        state = newState
        onStateChanged?.invoke(newState)
    }

    var onDataReceived: ((ByteArray) -> Unit)? = null

    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var txSubscribed = false
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    private val mAdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
            Log.i(tag, "LE Advertise Started.")
            advertiseCallback?.invoke(true)
            isAdvertising = true
            updateState(PeripheralState.advertising)
        }

        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            val statusText: String
            when (errorCode) {
                ADVERTISE_FAILED_ALREADY_STARTED -> {
                    statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                    isAdvertising = true
                    updateState(PeripheralState.advertising)
                    Log.i(tag, "LE Advertise $statusText")
                }
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                    statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    isAdvertising = false
                    updateState(PeripheralState.unsupported)
                    Log.i(tag, "LE Advertise $statusText")
                }
                ADVERTISE_FAILED_INTERNAL_ERROR -> {
                    statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                    isAdvertising = false
                    updateState(PeripheralState.idle)
                    Log.i(tag, "LE Advertise $statusText")
                }
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                    statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    isAdvertising = false
                    updateState(PeripheralState.unauthorized)
                    Log.i(tag, "LE Advertise $statusText")
                }
                ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                    statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    isAdvertising = false
                    updateState(PeripheralState.unauthorized)
                    Log.i(tag, "LE Advertise $statusText")
                }
                else -> {
                    statusText = "UNDOCUMENTED"
                    updateState(PeripheralState.idle)
                    Log.i(tag, "LE Advertise $statusText")
                }
            }

            Log.e(tag, "ERROR while starting advertising: $errorCode - $statusText")
            advertiseCallback?.invoke(false)
            isAdvertising = false
        }
    }

    fun init(context: Context) {
        this.context = context
        val bluetoothManager: BluetoothManager? =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()

        if (bluetoothManager == null || bluetoothAdapter == null) {
            Log.e(tag, "This device does not support bluetooth LE")
        } else {
            mBluetoothManager = bluetoothManager
            mBluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
        }
    }

    fun start(data: Data, settings: AdvertiseSettings, advertiseCallback: ((Boolean) -> Unit)) {
        this.advertiseCallback = advertiseCallback

        shouldAdvertise = true

        val advertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(UUID.fromString(data.serviceDataUuid)))
            .build()

        mBluetoothLeAdvertiser.startAdvertising(
            advertiseSettings,
            advertiseData,
            mAdvertiseCallback
        )

        addService(data)
    }

    fun isAdvertising(): Boolean {
        return isAdvertising
    }

    fun isConnected(): Boolean {
        return state == PeripheralState.connected
    }

    fun stop() {
        mBluetoothLeAdvertiser.stopAdvertising(mAdvertiseCallback)
        advertiseCallback?.invoke(false)
        isAdvertising = false
        shouldAdvertise = false

        updateState(PeripheralState.idle)
        Log.i(tag, "LE Advertise Stopped.")
    }

    private fun addService(data: Data) {
        Log.i(tag, "Add service")

        if (!shouldAdvertise) {
            return
        }

        txCharacteristic = BluetoothGattCharacteristic(
            UUID.fromString(data.txCharacteristicUUID),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        rxCharacteristic = BluetoothGattCharacteristic(
            UUID.fromString(data.rxCharacteristicUUID),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        val service = BluetoothGattService(
            UUID.fromString(data.serviceDataUuid),
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )

        val serverCallback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(
                device: BluetoothDevice?,
                status: Int,
                newState: Int
            ) {
                when (status) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        mBluetoothDevice = device
                        updateState(PeripheralState.connected)
                        Log.i(tag, "Device connected $device")
                    }

                    BluetoothProfile.STATE_DISCONNECTED -> {
                        mBluetoothDevice = null
                        updateState(PeripheralState.idle)
                        Log.i(tag, "Device disconnect $device")
                    }
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                Log.i(tag, "LE Read Request")

                val status = when (characteristic.uuid) {
                    rxCharacteristic?.uuid -> BluetoothGatt.GATT_SUCCESS
                    else -> BluetoothGatt.GATT_FAILURE
                }

                mBluetoothGattServer.sendResponse(device, requestId, status, 0, null)
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                Log.i(tag, "LE Write Request")

                val isValid = value?.isNotEmpty() == true && characteristic == rxCharacteristic

                if (isValid) {
                    onDataReceived?.invoke(value!!)
                    Log.i(tag, "LE Received Data $data")
                }

                if (responseNeeded) {
                    mBluetoothGattServer.sendResponse(
                        device,
                        requestId,
                        if (isValid) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,
                        0,
                        null
                    )
                }
            }
        }

        service.addCharacteristic(txCharacteristic)
        service.addCharacteristic(rxCharacteristic)

        mBluetoothGattServer = mBluetoothManager
            .openGattServer(context, serverCallback)
            .also { it.addService(service) }

        Log.i(tag, "Added service")
    }

    fun send(data: ByteArray) {
        Log.i(tag, "Send data: $data")

        if (mBluetoothDevice == null || txCharacteristic == null) {
            return
        }

        txCharacteristic!!.value = data
        mBluetoothGattServer.notifyCharacteristicChanged(mBluetoothDevice, txCharacteristic, false)
    }
}
