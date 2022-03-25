/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class FlutterBlePeripheralManager(context: Context) {

    var mBluetoothManager: BluetoothManager?
    var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null

    var pendingResultForActivityResult: MethodChannel.Result? = null
    val requestEnableBt = 4

    //TODO
//    private lateinit var mBluetoothGattServer: BluetoothGattServer
//    private var mBluetoothGatt: BluetoothGatt? = null
//    private var mBluetoothDevice: BluetoothDevice? = null
//    private var txCharacteristic: BluetoothGattCharacteristic? = null
//    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    init {
        mBluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    }

    /**
     * Enables bluetooth with a dialog or without.
     */
    fun enableBluetooth(call: MethodCall, result: MethodChannel.Result, activityBinding: ActivityPluginBinding) {
        if (mBluetoothManager!!.adapter.isEnabled) {
            result.success(true)
        } else {
            if (call.arguments as Boolean) {
                pendingResultForActivityResult = result
                val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                ActivityCompat.startActivityForResult(
                        activityBinding.activity,
                        intent,
                        requestEnableBt,
                        null
                )
            } else {
                mBluetoothManager!!.adapter.enable()
            }
        }
    }

    /**
     * Start advertising using the startAdvertising() method.
     */
    fun start(peripheralData: AdvertiseData, peripheralSettings: AdvertiseSettings, peripheralResponse: AdvertiseData?, mAdvertiseCallback: PeripheralAdvertisingCallback) {
        mBluetoothLeAdvertiser!!.startAdvertising(
                peripheralSettings,
                peripheralData,
                peripheralResponse,
                mAdvertiseCallback
        )

//        addService(peripheralData) TODO: Add service to advertise
    }

    /**
     * Start advertising using the startAdvertisingSet method.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(advertiseData: AdvertiseData, advertiseSettingsSet: AdvertisingSetParameters, peripheralResponse: AdvertiseData?,
                 periodicResponse: AdvertiseData?, periodicResponseSettings: PeriodicAdvertisingParameters?, maxExtendedAdvertisingEvents: Int = 0, duration: Int = 0, mAdvertiseSetCallback: PeripheralAdvertisingSetCallback) {

        mBluetoothLeAdvertiser!!.startAdvertisingSet(
                advertiseSettingsSet,
                advertiseData,
                peripheralResponse,
                periodicResponseSettings,
                periodicResponse,
                duration,
                maxExtendedAdvertisingEvents,
                mAdvertiseSetCallback,
        )

        // TODO: Add service to advertise
//        addService(peripheralData)
    }
}


// TODO: Add service to advertise
//
//    private fun addService() {
//        var txCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D4",
//        var rxCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D5",
//        txCharacteristic = BluetoothGattCharacteristic(
//            UUID.fromString(peripheralData.txCharacteristicUUID),
//            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
//            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
//        )
//
//        rxCharacteristic = BluetoothGattCharacteristic(
//            UUID.fromString(peripheralData.rxCharacteristicUUID),
//            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
//            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
//        )
//
//        val service = BluetoothGattService(
//            UUID.fromString(peripheralData.serviceDataUuid),
//            BluetoothGattService.SERVICE_TYPE_PRIMARY,
//        )
//
//        val gattCallback = object : BluetoothGattCallback() {
//            override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
//                onMtuChanged?.invoke(mtu)
//            }
//        }
//
//        val serverCallback = object : BluetoothGattServerCallback() {
//            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
//                onMtuChanged?.invoke(mtu)
//            }
//
//            override fun onConnectionStateChange(
//                device: BluetoothDevice?,
//                status: Int,
//                newState: Int
//            ) {
//                when (status) {
//                    BluetoothProfile.STATE_CONNECTED -> {
//                        mBluetoothDevice = device
//                        mBluetoothGatt = mBluetoothDevice?.connectGatt(context, true, gattCallback)
//                        stateChangedHandler.publishPeripheralState(PeripheralState.connected)
//                        Log.i(tag, "Device connected $device")
//                    }
//
//                    BluetoothProfile.STATE_DISCONNECTED -> {
//                        stateChangedHandler.publishPeripheralState(PeripheralState.idle)
//                        Log.i(tag, "Device disconnect $device")
//                    }
//                }
//            }
//
//            override fun onCharacteristicReadRequest(
//                device: BluetoothDevice,
//                requestId: Int,
//                offset: Int,
//                characteristic: BluetoothGattCharacteristic
//            ) {
//                Log.i(tag, "BLE Read Request")
//
//                val status = when (characteristic.uuid) {
//                    rxCharacteristic?.uuid -> BluetoothGatt.GATT_SUCCESS
//                    else -> BluetoothGatt.GATT_FAILURE
//                }
//
//                mBluetoothGattServer.sendResponse(device, requestId, status, 0, null)
//            }
//
//            override fun onCharacteristicWriteRequest(
//                device: BluetoothDevice,
//                requestId: Int,
//                characteristic: BluetoothGattCharacteristic,
//                preparedWrite: Boolean,
//                responseNeeded: Boolean,
//                offset: Int,
//                value: ByteArray?
//            ) {
//                Log.i(tag, "BLE Write Request")
//
//                val isValid = value?.isNotEmpty() == true && characteristic == rxCharacteristic
//
//                Log.i(tag, "BLE Write Request - Is valid? $isValid")
//
//                if (isValid) {
//                    mBluetoothDevice = device
//                    mBluetoothGatt = mBluetoothDevice?.connectGatt(context, true, gattCallback)
//                    stateChangedHandler.publishPeripheralState(PeripheralState.connected)
//
//                    onDataReceived?.invoke(value!!)
//                    Log.i(tag, "BLE Received Data $peripheralData")
//                }
//
//                if (responseNeeded) {
//                    Log.i(tag, "BLE Write Request - Response")
//                    mBluetoothGattServer.sendResponse(
//                        device,
//                        requestId,
//                        BluetoothGatt.GATT_SUCCESS,
//                        0,
//                        null
//                    )
//                }
//            }
//        }
//
//        service.addCharacteristic(txCharacteristic)
//        service.addCharacteristic(rxCharacteristic)
//
//        mBluetoothGattServer = mBluetoothManager
//            .openGattServer(context, serverCallback)
//            .also { it.addService(service) }
//    }
//
//    fun send(data: ByteArray) {
//        txCharacteristic?.let { char ->
//            char.value = data
//            mBluetoothGatt?.writeCharacteristic(char)
//            mBluetoothGattServer.notifyCharacteristicChanged(mBluetoothDevice, char, false)
//        }
//    }
