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
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralData
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*


class FlutterBlePeripheralManager {
    private val tag: String = "BLE Peripheral"
    private lateinit var mBluetoothManager: BluetoothManager
    private lateinit var mBluetoothGattServer: BluetoothGattServer
    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var mBluetoothGatt: BluetoothGatt? = null
    private var mBluetoothDevice: BluetoothDevice? = null

    private lateinit var context: Context

    private var isAdvertising = false
//    private var shouldAdvertise = false

    var onMtuChanged: ((Int) -> Unit)? = null

    private var state = PeripheralState.idle
    var onStateChanged: ((PeripheralState) -> Unit)? = null
    private fun updateState(newState: PeripheralState) {
        state = newState
        onStateChanged?.invoke(newState)
    }

    var onDataReceived: ((ByteArray) -> Unit)? = null

    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    fun handlePeripheralException(e: PeripheralException, result: MethodChannel.Result?) {
        if (e.message == "Not Supported") {
            updateState(PeripheralState.unsupported)
            Log.e(tag, "This device does not support bluetooth LE")
            result?.error("Not Supported", "This device does not support bluetooth LE", null)
        } else {
            updateState(PeripheralState.unsupported)
            Log.e(tag, "Bluetooth may be turned off or is not supported")
            result?.error("Not powered", "Bluetooth may be turned off or is not supported", null)
        }
    }

    private val mAdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
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
                    Log.i(tag, "BLE Advertise $statusText")
                }
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                    statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    isAdvertising = false
                    updateState(PeripheralState.unsupported)
                    Log.i(tag, "BLE Advertise $statusText")
                }
                ADVERTISE_FAILED_INTERNAL_ERROR -> {
                    statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                    isAdvertising = false
                    updateState(PeripheralState.idle)
                    Log.i(tag, "BLE Advertise $statusText")
                }
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                    statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    isAdvertising = false
                    updateState(PeripheralState.unauthorized)
                    Log.i(tag, "BLE Advertise $statusText")
                }
                ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                    statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    isAdvertising = false
                    updateState(PeripheralState.unsupported)
                    Log.i(tag, "BLE Advertise $statusText")
                }
                else -> {
                    statusText = "UNDOCUMENTED"
                    updateState(PeripheralState.idle)
                    Log.i(tag, "BLE Advertise $statusText")
                }
            }

            Log.e(tag, "ERROR while starting advertising: $errorCode - $statusText")
            isAdvertising = false
        }
    }

    fun init(context: Context) {
        this.context = context

        val bluetoothManager: BluetoothManager? =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

        if (bluetoothManager == null) {
            throw PeripheralException("Not Supported")
        } else {
            val bluetoothAdapter: BluetoothAdapter = bluetoothManager.adapter
            mBluetoothManager = bluetoothManager
            if (bluetoothAdapter.bluetoothLeAdvertiser == null) {
                throw PeripheralException("Not powered")
            } else {
                mBluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
            }
        }
    }

    fun start(peripheralData: PeripheralData, result: MethodChannel.Result) {
        try {
            init(context)
        } catch (e: PeripheralException) {
            handlePeripheralException(e, result)
            return
        }

//        shouldAdvertise = true

        val advertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode(peripheralData.advertiseMode)
            .setConnectable(peripheralData.connectable)
            .setTimeout(peripheralData.timeout)
            .setTxPowerLevel(peripheralData.txPowerLevel)
            .build()

        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(peripheralData.includeDeviceName)
            .setIncludeTxPowerLevel(peripheralData.includeTxPowerLevel)
            .addServiceUuid(ParcelUuid(UUID.fromString(peripheralData.uuid)))
            .build()

        mBluetoothLeAdvertiser!!.startAdvertising(
            advertiseSettings,
            advertiseData,
            mAdvertiseCallback
        )

        // TODO: Add service to advertise
//        addService(peripheralData)
    }

    fun isAdvertising(): Boolean {
        return isAdvertising
    }

    fun isConnected(): Boolean {
        return state == PeripheralState.connected
    }

    fun stop(result: MethodChannel.Result) {
        try {
            init(context)
        } catch (e: PeripheralException) {
            handlePeripheralException(e, result)
            return
        }

        mBluetoothLeAdvertiser!!.stopAdvertising(mAdvertiseCallback)
        isAdvertising = false
//        shouldAdvertise = false

        updateState(PeripheralState.idle)
    }

    // TODO: Add service to advertise
    private fun addService(peripheralData: PeripheralData) {
//        if (!shouldAdvertise) {
//            return
//        }

        txCharacteristic = BluetoothGattCharacteristic(
            UUID.fromString(peripheralData.txCharacteristicUUID),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        rxCharacteristic = BluetoothGattCharacteristic(
            UUID.fromString(peripheralData.rxCharacteristicUUID),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        val service = BluetoothGattService(
            UUID.fromString(peripheralData.serviceDataUuid),
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )

        val gattCallback = object : BluetoothGattCallback() {
            override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
                onMtuChanged?.invoke(mtu)
            }
        }

        val serverCallback = object : BluetoothGattServerCallback() {
            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
                onMtuChanged?.invoke(mtu)
            }

            override fun onConnectionStateChange(
                device: BluetoothDevice?,
                status: Int,
                newState: Int
            ) {
                when (status) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        mBluetoothDevice = device
                        mBluetoothGatt = mBluetoothDevice?.connectGatt(context, true, gattCallback)
                        updateState(PeripheralState.connected)
                        Log.i(tag, "Device connected $device")
                    }

                    BluetoothProfile.STATE_DISCONNECTED -> {
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
                Log.i(tag, "BLE Read Request")

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
                Log.i(tag, "BLE Write Request")

                val isValid = value?.isNotEmpty() == true && characteristic == rxCharacteristic

                Log.i(tag, "BLE Write Request - Is valid? $isValid")

                if (isValid) {
                    mBluetoothDevice = device
                    mBluetoothGatt = mBluetoothDevice?.connectGatt(context, true, gattCallback)
                    updateState(PeripheralState.connected)

                    onDataReceived?.invoke(value!!)
                    Log.i(tag, "BLE Received Data $peripheralData")
                }

                if (responseNeeded) {
                    Log.i(tag, "BLE Write Request - Response")
                    mBluetoothGattServer.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
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
    }

    fun send(data: ByteArray) {
        txCharacteristic?.let { char ->
            char.value = data
            mBluetoothGatt?.writeCharacteristic(char)
            mBluetoothGattServer.notifyCharacteristicChanged(mBluetoothDevice, char, false)
        }
    }
}
