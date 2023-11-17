/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.Manifest
import android.app.Activity
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import dev.steenbakker.flutter_ble_peripheral.models.PermissionState
import dev.steenbakker.flutter_ble_peripheral.models.State
import io.flutter.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class FlutterBlePeripheralManager(context: Context) {

    companion object {
        const val REQUEST_ENABLE_BT = 4
        const val REQUEST_PERMISSION_BT = 8
    }

    var mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null

    var pendingResultForActivityResult: MethodChannel.Result? = null
    var pendingResultForPermissionResult: MethodChannel.Result? = null

    //TODO
//    private lateinit var mBluetoothGattServer: BluetoothGattServer
//    private var mBluetoothGatt: BluetoothGatt? = null
//    private var mBluetoothDevice: BluetoothDevice? = null
//    private var txCharacteristic: BluetoothGattCharacteristic? = null
//    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    // Permissions for Bluetooth API > 31
    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothAdvertisePermission(context: Context): Boolean {
        return (context.checkSelfPermission(
            Manifest.permission.BLUETOOTH_ADVERTISE
        )
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothConnectPermission(context: Context): Boolean {
        return (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun hasLocationFinePermission(context: Context): Boolean {
        return (context.checkSelfPermission(
            Manifest.permission.ACCESS_FINE_LOCATION
        )
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun hasLocationCoarsePermission(context: Context): Boolean {
        return (context.checkSelfPermission(
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
                == PackageManager.PERMISSION_GRANTED)
    }

    /**
     * Enables bluetooth with a dialog or without.
     */
    fun checkAndEnableBluetooth(shouldAsk: Boolean, result: MethodChannel.Result, activityBinding: ActivityPluginBinding): Boolean {
        return if (mBluetoothManager!!.adapter.isEnabled) {
            true
        } else {
            pendingResultForPermissionResult = result
            val hasPermission = requestPermission(activityBinding.activity, result)
            if (hasPermission == State.Granted) enableBluetooth(shouldAsk, result, activityBinding, false)
            false
        }
    }
    fun requestPermission(activity: Activity, result: MethodChannel.Result?): State? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!hasBluetoothAdvertisePermission(activity) || !hasBluetoothConnectPermission(activity)) {
                if (result != null) {
                    pendingResultForPermissionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(
                            Manifest.permission.BLUETOOTH_CONNECT,
                            Manifest.permission.BLUETOOTH_ADVERTISE
                        ),
                        REQUEST_PERMISSION_BT
                    )
                    return null
                }
                if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.BLUETOOTH_ADVERTISE) ||
                    ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.BLUETOOTH_CONNECT)) {
                    return State.Denied
                }
                return State.PermanentlyDenied
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (!hasLocationCoarsePermission(activity) || !hasLocationFinePermission(activity)) {
                if (result != null) {
                    pendingResultForPermissionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        ),
                        REQUEST_PERMISSION_BT
                    )
                    return null
                }
                if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_FINE_LOCATION) ||
                    ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_COARSE_LOCATION)) {
                    return State.Denied
                }
                return State.PermanentlyDenied
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!hasLocationCoarsePermission(activity)) {
                if (result != null) {
                    pendingResultForPermissionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
                        REQUEST_PERMISSION_BT
                    )
                    return null
                }
                if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_COARSE_LOCATION)) {
                    return State.Denied
                }
                return State.PermanentlyDenied
            }
        }
        return State.Granted
    }

    fun enableBluetooth(ask: Boolean, result: MethodChannel.Result?, activityBinding: ActivityPluginBinding, askForPermission: Boolean) {
        if (ask && pendingResultForActivityResult == null) {
            if (askForPermission) {
                pendingResultForPermissionResult = result
            } else {
                pendingResultForActivityResult = result
            }

            ActivityCompat.startActivityForResult(
                activityBinding.activity,
                Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                REQUEST_ENABLE_BT,
                null
            )
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU){
            @Suppress("DEPRECATION")
            mBluetoothManager!!.adapter.enable()
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

    fun stop(advertisingCallback: AdvertiseCallback) {
        mBluetoothLeAdvertiser!!.stopAdvertising(advertisingCallback)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun stopSet(advertisingSetCallback: AdvertisingSetCallback) {
        mBluetoothLeAdvertiser!!.stopAdvertisingSet(advertisingSetCallback)
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
