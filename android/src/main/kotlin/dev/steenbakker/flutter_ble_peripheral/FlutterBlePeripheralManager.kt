/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.app.Activity
import android.bluetooth.*
import android.bluetooth.le.*
import android.bluetooth.le.AdvertisingSetCallback
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.*
import io.flutter.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*


class FlutterBlePeripheralManager(context: Context, val stateChangedHandler: StateChangedHandler) {

    private val tag: String = "BLE Peripheral"
    private lateinit var mBluetoothManager: BluetoothManager
    private lateinit var mBluetoothGattServer: BluetoothGattServer
    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var mBluetoothGatt: BluetoothGatt? = null
    private var mBluetoothDevice: BluetoothDevice? = null


    private var isAdvertising = false

//    var onMtuChanged: ((Int) -> Unit)? = null
//    var onStateChanged: ((PeripheralState) -> Unit)? = null
//    var onDataReceived: ((ByteArray) -> Unit)? = null
//    val stateChange: StateChangedHandler = StateChangedHandler()

    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    private var isSet = false

    var result: MethodChannel.Result? = null

    init {
        val bluetoothManager: BluetoothManager? =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

        if (bluetoothManager == null) {
            throw PeripheralException(PeripheralState.unsupported)
        } else {
            mBluetoothManager = bluetoothManager

            val bluetoothAdapter: BluetoothAdapter = bluetoothManager.adapter
            //&& !bluetoothAdapter.isMultipleAdvertisementSupported
            if (bluetoothAdapter.bluetoothLeAdvertiser == null) {
                throw PeripheralException(PeripheralState.unsupported)
            } else {
//                bluetoothAdapter.state
                mBluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
                 if (bluetoothAdapter.bluetoothLeAdvertiser == null) {
                     stateChangedHandler.publishPeripheralState(PeripheralState.poweredOff)
                 }
                stateChangedHandler.publishPeripheralState(PeripheralState.idle)
            }
        }
    }

    var pendingResultForActivityResult: MethodChannel.Result? = null
    private val requestEnableBt = 4

    fun enableBluetooth(call: MethodCall, result: MethodChannel.Result, activityBinding: ActivityPluginBinding) {
        if (mBluetoothManager.adapter.isEnabled) {
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
                mBluetoothManager.adapter.enable()
            }
        }
    }

    private fun handlePeripheralException(e: PeripheralException, result: MethodChannel.Result?) {
        when (e.state) {
            PeripheralState.unsupported -> {
                stateChangedHandler.publishPeripheralState(PeripheralState.unsupported)
                Log.e(tag, "This device does not support bluetooth LE")
                result?.error("Not Supported", "This device does not support bluetooth LE", e.state.name)
            }
            PeripheralState.poweredOff -> {
                stateChangedHandler.publishPeripheralState(PeripheralState.poweredOff)
                Log.e(tag, "Bluetooth may be turned off")
                result?.error("Not powered", "Bluetooth may be turned off", e.state.name)
            }
            else -> {
                stateChangedHandler.publishPeripheralState(e.state)
                Log.e(tag, e.state.name)
                result?.error(e.state.name, null, null)
            }
        }
    }

    private val mAdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
            isAdvertising = true
            result?.success(null)
            result = null
            stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
        }

        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            val statusText: String
            when (errorCode) {
                ADVERTISE_FAILED_ALREADY_STARTED -> {
                    statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                    isAdvertising = true
                    stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
                }
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                    statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.unsupported)
                }
                ADVERTISE_FAILED_INTERNAL_ERROR -> {
                    statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.idle)
                }
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                    statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.idle)
                }
                ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                    statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.idle)
                }
                else -> {
                    statusText = "UNDOCUMENTED"
                    stateChangedHandler.publishPeripheralState(PeripheralState.unknown)
                }
            }
            Log.e(tag, "ERROR while starting advertising: $errorCode - $statusText")
            result?.error(statusText, null, null)
            result = null
            isAdvertising = false
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private val mAdvertiseSetCallback = object : AdvertisingSetCallback() {

        /**
         * Callback triggered in response to {@link BluetoothLeAdvertiser#startAdvertisingSet}
         * indicating result of the operation. If status is ADVERTISE_SUCCESS, then advertisingSet
         * contains the started set and it is advertising. If error occurred, advertisingSet is
         * null, and status will be set to proper error code.
         *
         * @param advertisingSet The advertising set that was started or null if error.
         * @param txPower tx power that will be used for this set.
         * @param status Status of the operation.
         */

        override fun onAdvertisingSetStarted(
            advertisingSet: AdvertisingSet?,
            txPower: Int,
            status: Int
        ) {
            Log.i("FlutterBlePeripheral", "onAdvertisingSetStarted() status: $advertisingSet, txPOWER $txPower, status $status")
            super.onAdvertisingSetStarted(advertisingSet, txPower, status)
            var statusText = ""
            when (status) {
                ADVERTISE_SUCCESS -> {
                    isAdvertising = true
                    result?.success(txPower)
                    stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
                }
                ADVERTISE_FAILED_ALREADY_STARTED -> {
                    statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                    isAdvertising = true
                    stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
                }
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                    statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.unsupported)
                }
                ADVERTISE_FAILED_INTERNAL_ERROR -> {
                    statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.idle)
                }
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                    statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.idle)
                }
                ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                    statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    isAdvertising = false
                    stateChangedHandler.publishPeripheralState(PeripheralState.idle)
                }
                else -> {
                    statusText = "UNDOCUMENTED"
                    stateChangedHandler.publishPeripheralState(PeripheralState.unknown)
                }

            }
            if (status != ADVERTISE_SUCCESS) {
                Log.e(tag, "ERROR while starting advertising set: $status - $statusText")
                result?.error(status.toString(), statusText, "startAdvertisingSet")
                result = null
            }

        }

        /**
         * Callback triggered in response to [BluetoothLeAdvertiser.stopAdvertisingSet]
         * indicating advertising set is stopped.
         *
         * @param advertisingSet The advertising set.
         */
        override fun onAdvertisingSetStopped(advertisingSet: AdvertisingSet?) {
            Log.i("FlutterBlePeripheral", "onAdvertisingSetStopped() status: $advertisingSet")
            super.onAdvertisingSetStopped(advertisingSet)
            isAdvertising = false
            stateChangedHandler.publishPeripheralState(PeripheralState.idle)
        }

        /**
         * Callback triggered in response to [BluetoothLeAdvertiser.startAdvertisingSet]
         * indicating result of the operation. If status is ADVERTISE_SUCCESS, then advertising set is
         * advertising.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onAdvertisingEnabled(
            advertisingSet: AdvertisingSet?,
            enable: Boolean,
            status: Int
        ) {
            Log.i("FlutterBlePeripheral", "onAdvertisingEnabled() status: $advertisingSet, enable $enable, status $status")
            super.onAdvertisingEnabled(advertisingSet, enable, status)
            isAdvertising = true
            stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setAdvertisingData] indicating
         * result of the operation. If status is ADVERTISE_SUCCESS, then data was changed.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onAdvertisingDataSet(advertisingSet: AdvertisingSet?, status: Int) {
            Log.i("FlutterBlePeripheral", "onAdvertisingDataSet() status: $advertisingSet, status $status")
            super.onAdvertisingDataSet(advertisingSet, status)
            isAdvertising = true
            stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setAdvertisingData] indicating
         * result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onScanResponseDataSet(advertisingSet: AdvertisingSet?, status: Int) {
            Log.i("FlutterBlePeripheral", "onScanResponseDataSet() status: $advertisingSet, status $status")
            super.onAdvertisingDataSet(advertisingSet, status)
            isAdvertising = true
            stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setAdvertisingParameters]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param txPower tx power that will be used for this set.
         * @param status Status of the operation.
         */
        override fun onAdvertisingParametersUpdated(
            advertisingSet: AdvertisingSet?,
            txPower: Int, status: Int
        ) {
            Log.i("FlutterBlePeripheral", "onAdvertisingParametersUpdated() status: $advertisingSet, txPOWER $txPower, status $status")
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setPeriodicAdvertisingParameters]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onPeriodicAdvertisingParametersUpdated(
            advertisingSet: AdvertisingSet?,
            status: Int
        ) {
            Log.i("FlutterBlePeripheral", "onPeriodicAdvertisingParametersUpdated() status: $advertisingSet, status $status")
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setPeriodicAdvertisingData]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onPeriodicAdvertisingDataSet(
            advertisingSet: AdvertisingSet?,
            status: Int
        ) {
            Log.i("FlutterBlePeripheral", "onPeriodicAdvertisingDataSet() status: $advertisingSet, status $status")
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setPeriodicAdvertisingEnabled]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onPeriodicAdvertisingEnabled(
            advertisingSet: AdvertisingSet?, enable: Boolean,
            status: Int
        ) {
            Log.i("FlutterBlePeripheral", "onPeriodicAdvertisingEnabled() status: $advertisingSet, enable $enable, status $status")
        }
    }

    /**
     * Start continuous advertising
     */
    fun start(peripheralData: AdvertiseData, peripheralSettings: AdvertiseSettings, result: MethodChannel.Result, peripheralResponse: AdvertiseData?) {
//        try {
//            init(context)
//        } catch (e: PeripheralException) {
//            handlePeripheralException(e, result)
//            return
//        }

        this.result = result

        isSet = false
        mBluetoothLeAdvertiser!!.startAdvertising(
            peripheralSettings,
            peripheralData,
                peripheralResponse,
            mAdvertiseCallback
        )

//        addService(peripheralData) TODO: Add service to advertise
    }

    /**
     * Start advertising for a certain period
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(advertiseData: AdvertiseData, advertiseSettingsSet: AdvertisingSetParameters, result: MethodChannel.Result, peripheralResponse: AdvertiseData?,
                 periodicResponse: AdvertiseData?, periodicResponseSettings: PeriodicAdvertisingParameters?, maxExtendedAdvertisingEvents: Int = 0, duration: Int = 0) {
//        try {
//            init(context)
//        } catch (e: PeripheralException) {
//            handlePeripheralException(e, result)
//            return
//        }

        this.result = result

        isSet = true
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

    fun isAdvertising(): Boolean {
        return isAdvertising
    }

    fun stop(result: MethodChannel.Result) {
//        try {
//            init(context)
//        } catch (e: PeripheralException) {
//            handlePeripheralException(e, result)
//            return
//        }
        if (isSet) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                mBluetoothLeAdvertiser!!.stopAdvertisingSet(mAdvertiseSetCallback)
            }

        } else {
            mBluetoothLeAdvertiser!!.stopAdvertising(mAdvertiseCallback)
            isAdvertising = false
            stateChangedHandler.publishPeripheralState(PeripheralState.idle)
        }

    }

    // TODO: Add service to advertise
    private fun addService() {
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
    }

    fun send(data: ByteArray) {
        txCharacteristic?.let { char ->
            char.value = data
            mBluetoothGatt?.writeCharacteristic(char)
            mBluetoothGattServer.notifyCharacteristicChanged(mBluetoothDevice, char, false)
        }
    }
}
