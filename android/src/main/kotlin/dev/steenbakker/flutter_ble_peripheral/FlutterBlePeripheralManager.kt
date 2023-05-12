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
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import io.flutter.Log
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.plugin.common.MethodChannel


class FlutterBlePeripheralManager(context: Context, private val stateChangedHandler : StateChangedHandler) {
    companion object {
        const val TAG: String = "FlutterBlePeripheralManager"
    }

    private var mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null

    private var advertisingSetCallback: AdvertisingSetCallback? = null
    private var advertiseCallback: AdvertiseCallback? = null


    fun isEnabled() : Boolean {
        if (mBluetoothManager == null) throw PeripheralException(PeripheralState.unsupported)
        return mBluetoothManager!!.adapter.isEnabled
    }

    fun enableBluetooth(result: MethodChannel.Result) {
        if (mBluetoothManager == null) throw PeripheralException(PeripheralState.unsupported)
        mBluetoothManager!!.adapter.enable()
        result.success(true) //TODO: Handler Looper etc????
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
        advertiseCallback = PeripheralAdvertisingCallback(result, stateChangedHandler)

        mBluetoothLeAdvertiser!!.startAdvertising(
                peripheralSettings,
                peripheralData,
                peripheralResponse,
                advertiseCallback,
        )

//        addService(peripheralData) TODO: Add service to advertise
    }

    /**
     * Start advertising using the startAdvertisingSet method.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(advertiseData: AdvertiseData, advertiseSettingsSet: AdvertisingSetParameters, peripheralResponse: AdvertiseData?,
                 periodicResponse: AdvertiseData?, periodicResponseSettings: PeriodicAdvertisingParameters?, maxExtendedAdvertisingEvents: Int = 0, duration: Int = 0, result : MethodChannel.Result) {

        checkBluetoothState()
        advertisingSetCallback = PeripheralAdvertisingSetCallback(result, stateChangedHandler)

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

        // TODO: Add service to advertise
//        addService(peripheralData)
    }

    fun stop(result: MethodChannel.Result) {
        checkBluetoothState()

        if (advertisingSetCallback != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mBluetoothLeAdvertiser!!.stopAdvertisingSet(advertisingSetCallback!!)
            advertisingSetCallback = null
        } else {
            mBluetoothLeAdvertiser!!.stopAdvertising(advertiseCallback!!)
            advertiseCallback = null

            stateChangedHandler.publishPeripheralState(PeripheralState.idle)
        }

        result.success(null)
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
