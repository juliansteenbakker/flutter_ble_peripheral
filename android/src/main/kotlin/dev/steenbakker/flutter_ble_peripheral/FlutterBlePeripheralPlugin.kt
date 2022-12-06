/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.PeriodicAdvertisingParameters
import android.content.Context
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralManagerDelegate
import dev.steenbakker.flutter_ble_peripheral.exceptions.PermissionNotFoundException
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.*
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.*


class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private var methodChannel: MethodChannel? = null
    private val tag: String = "flutter_ble_peripheral"
    private var flutterBlePeripheralManager: FlutterBlePeripheralManager? = null

    private lateinit var stateChangedHandler: StateChangedHandler
    private var context: Context? = null

    private var activityBinding: ActivityPluginBinding? = null

    private var bluetoothReceiver: PeripheralManagerDelegate? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(
                flutterPluginBinding.binaryMessenger,
                "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel?.setMethodCallHandler(this)


        stateChangedHandler = StateChangedHandler(flutterPluginBinding)
        flutterBlePeripheralManager = FlutterBlePeripheralManager(flutterPluginBinding.applicationContext)

        bluetoothReceiver = PeripheralManagerDelegate(stateChangedHandler)
        context!!.registerReceiver(bluetoothReceiver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        context!!.unregisterReceiver(bluetoothReceiver)
        methodChannel = null
        flutterBlePeripheralManager = null
        context = null
        bluetoothReceiver = null
    }

    private fun checkBluetoothState(enable: Boolean): PeripheralState? {
        if (flutterBlePeripheralManager!!.mBluetoothManager == null || flutterBlePeripheralManager!!.mBluetoothManager?.adapter == null) {
            return PeripheralState.unsupported
        } else {
            // Can't check whether ble is turned off or not supported, see https://stackoverflow.com/questions/32092902/why-ismultipleadvertisementsupported-returns-false-when-getbluetoothleadverti
            // !bluetoothAdapter.isMultipleAdvertisementSupported
            flutterBlePeripheralManager!!.mBluetoothLeAdvertiser = flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.bluetoothLeAdvertiser
            if (!flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.isEnabled) {

                if(enable) flutterBlePeripheralManager!!.enableBluetooth(null, null, activityBinding!!)
                return PeripheralState.poweredOff
            } else {
                val hasPermission = flutterBlePeripheralManager!!.requestPermission(activityBinding!!, enable)
                if (!hasPermission) return PeripheralState.unauthorized
            }
        }
        return null
    }


    private fun enableBluetooth(call: MethodCall, result: MethodChannel.Result) {
        if (activityBinding != null) {
            this.call = call
            this.pendingResultForPermission = result
            flutterBlePeripheralManager!!.checkAndEnableBluetooth(call, result, activityBinding!!)
        } else {
            result.error("No activity", "FlutterBlePeripheral is not correctly initialized", "null")
        }
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null || context == null) {
            result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", "null")
        }

        if (call.method == "start" || call.method == "stop") {
            val state = checkBluetoothState(true)
            if (state != null) {
                stateChangedHandler.publishPeripheralState(state)
                result.error(state.value.toString(), state.name, "startAdvertising")
                return
            }
        }
        try {
            when (call.method) {
                "start" -> startPeripheral(call, result)
                "stop" -> stopPeripheral(result)
                "isAdvertising" -> Handler(Looper.getMainLooper()).post {
                    result.success(stateChangedHandler.state == PeripheralState.advertising)
                }
                "isSupported" -> isSupported(result, context!!)
                "isConnected" -> isConnected(result)
                "enableBluetooth" -> enableBluetooth(call, result)
                "requestPermission" -> requestPermission(result)
//                    "sendData" -> sendData(call, result)
                else -> Handler(Looper.getMainLooper()).post {
                    result.notImplemented()
                }
            }
        } catch (e: PermissionNotFoundException) {
            result.error(
                    "No Permission",
                    "No permission for ${e.message} Please ask runtime permission.",
                    "Manifest.permission.${e.message}"
            )
        }


    }

    @Suppress("UNCHECKED_CAST")
    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {
//        hasPermissions(context!!)

        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<String, Any>

        // First build main advertise data.
        val advertiseData: AdvertiseData.Builder = AdvertiseData.Builder()
        (arguments["manufacturerData"] as ByteArray?)?.let { advertiseData.addManufacturerData((arguments["manufacturerId"] as Int), it) }
        (arguments["serviceData"] as ByteArray?)?.let { advertiseData.addServiceData(ParcelUuid(UUID.fromString(arguments["serviceDataUuid"] as String)), it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            (arguments["serviceSolicitationUuid"] as String?)?.let { advertiseData.addServiceSolicitationUuid(
                    ParcelUuid(UUID.fromString(it))) }

        (arguments["uuid"] as String?)?.let { advertiseData.addServiceUuid(ParcelUuid(UUID.fromString(it))) }
        //TODO: addTransportDiscoveryData
        (arguments["includeDeviceName"] as Boolean?)?.let { advertiseData.setIncludeDeviceName(it) }
        (arguments["transmissionPowerIncluded"] as Boolean?)?.let {
            advertiseData.setIncludeTxPowerLevel(it)
        }

        // Build advertise response data if provided
        var advertiseResponseData: AdvertiseData.Builder? = null
        if ((arguments["responseManufacturerData"] as ByteArray?) != null || (arguments["responseServiceDataUuid"] as ByteArray?) != null || (arguments["responseServiceUuid"] as String?) != null) {
            advertiseResponseData = AdvertiseData.Builder()
            (arguments["responseManufacturerData"] as ByteArray?)?.let { advertiseData.addManufacturerData((arguments["responseManufacturerId"] as Int), it) }
            (arguments["responseServiceData"] as ByteArray?).let { advertiseData.addServiceData(ParcelUuid(UUID.fromString(arguments["responseServiceDataUuid"] as String)), it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                (arguments["responseServiceSolicitationUuid"] as String?)?.let { advertiseData.addServiceSolicitationUuid(
                        ParcelUuid(UUID.fromString(it))) }

            (arguments["responseServiceUuid"] as String?)?.let { advertiseData.addServiceUuid(ParcelUuid(UUID.fromString(it))) }
            //TODO: addTransportDiscoveryData
            (arguments["responseIncludeDeviceName"] as Boolean?)?.let { advertiseData.setIncludeDeviceName(it) }
            (arguments["responseTransmissionPowerIncluded"] as Boolean?)?.let {
                advertiseData.setIncludeTxPowerLevel(it)
            }
        }

        // Check if we should use the advertiseSet method instead of advertise
        if (arguments["advertiseSet"] as Boolean? == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {


            val advertiseSettingsSet: AdvertisingSetParameters.Builder = AdvertisingSetParameters.Builder()
            (arguments["anonymous"] as Boolean?)?.let { advertiseSettingsSet.setAnonymous(it) }
            (arguments["connectable"] as Boolean?)?.let { advertiseSettingsSet.setConnectable(it) }
            (arguments["setIncludeTxPower"] as Boolean?)?.let { advertiseSettingsSet.setIncludeTxPower(it) }
            (arguments["interval"] as Int?)?.let { advertiseSettingsSet.setInterval(it) }
            (arguments["legacyMode"] as Boolean?)?.let { advertiseSettingsSet.setLegacyMode(it) }
            (arguments["primaryPhy"] as Int?)?.let { advertiseSettingsSet.setPrimaryPhy(it) }
            (arguments["scannable"] as Boolean?)?.let { advertiseSettingsSet.setScannable(it) }
            (arguments["secondaryPhy"] as Int?)?.let { advertiseSettingsSet.setSecondaryPhy(it) }
            (arguments["txPowerLevel"] as Int?)?.let { advertiseSettingsSet.setTxPowerLevel(it) }

            var periodicAdvertiseData: AdvertiseData.Builder? = null
            var periodicAdvertiseDataSettings: PeriodicAdvertisingParameters.Builder? = null
            if ((arguments["periodicManufacturerData"] as ByteArray?) != null || (arguments["periodicServiceDataUuid"] as ByteArray?) != null || (arguments["periodicServiceUuid"] as String?) != null) {
                periodicAdvertiseData = AdvertiseData.Builder()
                periodicAdvertiseDataSettings = PeriodicAdvertisingParameters.Builder()

                (arguments["periodicManufacturerData"] as ByteArray?)?.let {
                    periodicAdvertiseData.addManufacturerData(
                            (arguments["periodicManufacturerId"] as Int),
                            it
                    )
                }
                (arguments["periodicServiceData"] as ByteArray?).let {
                    periodicAdvertiseData.addServiceData(
                            ParcelUuid(UUID.fromString(arguments["periodicServiceDataUuid"] as String)),
                            it
                    )
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    (arguments["periodicServiceSolicitationUuid"] as String?)?.let {
                        periodicAdvertiseData.addServiceSolicitationUuid(
                                ParcelUuid(UUID.fromString(it))
                        )
                    }

                (arguments["periodicServiceUuid"] as String?)?.let {
                    periodicAdvertiseData.addServiceUuid(
                            ParcelUuid(UUID.fromString(it))
                    )
                }
                //TODO: addTransportDiscoveryData
                (arguments["periodicIncludeDeviceName"] as Boolean?)?.let {
                    periodicAdvertiseData.setIncludeDeviceName(
                            it
                    )
                }
                (arguments["periodicTransmissionPowerIncluded"] as Boolean?)?.let {
                    periodicAdvertiseData.setIncludeTxPowerLevel(it)
                }

                (arguments["periodicTransmissionPowerIncluded"] as Boolean?)?.let {
                    periodicAdvertiseDataSettings.setIncludeTxPower(it)
                }

                (arguments["interval"] as Int?)?.let {
                    periodicAdvertiseDataSettings.setInterval(it)
                }

            }

            var maxExtendedAdvertisingEvents = 0
            var duration = 0
            (arguments["maxExtendedAdvertisingEvents"] as Int?)?.let { maxExtendedAdvertisingEvents = it }
            (arguments["duration"] as Int?)?.let { duration = it }

            advertisingSetCallback = PeripheralAdvertisingSetCallback(result, stateChangedHandler)

            flutterBlePeripheralManager!!.startSet(advertiseData.build(), advertiseSettingsSet.build(), advertiseResponseData?.build(), periodicAdvertiseData?.build(), periodicAdvertiseDataSettings?.build(),
                    maxExtendedAdvertisingEvents, duration, advertisingSetCallback!!)
        } else {
            // Setup the advertiseSettings
            val advertiseSettings: AdvertiseSettings.Builder = AdvertiseSettings.Builder()

            (arguments["advertiseMode"] as Int?)?.let { advertiseSettings.setAdvertiseMode(it) }
            (arguments["connectable"] as Boolean?)?.let { advertiseSettings.setConnectable(it) }
            (arguments["timeout"] as Int?)?.let { advertiseSettings.setTimeout(it) }
            (arguments["txPowerLevel"] as Int?)?.let { advertiseSettings.setTxPowerLevel(it) }

            advertisingCallback = PeripheralAdvertisingCallback(result, stateChangedHandler)

            flutterBlePeripheralManager!!.start(advertiseData.build(), advertiseSettings.build(), advertiseResponseData?.build(), advertisingCallback!!)
        }
    }

    private var advertisingSetCallback: PeripheralAdvertisingSetCallback? = null
    private var advertisingCallback: PeripheralAdvertisingCallback? = null

    private fun stopPeripheral(result: MethodChannel.Result) {
        if (advertisingSetCallback != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            flutterBlePeripheralManager!!.mBluetoothLeAdvertiser!!.stopAdvertisingSet(advertisingSetCallback)
        } else {
            flutterBlePeripheralManager!!.mBluetoothLeAdvertiser!!.stopAdvertising(advertisingCallback)
        }


        stateChangedHandler.publishPeripheralState(PeripheralState.idle)

        Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Stop advertise")
            result.success(null)
        }
    }

    private fun isSupported(result: MethodChannel.Result, context: Context) {
        val isSupported = context.packageManager?.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)

        Handler(Looper.getMainLooper()).post {
            result.success(isSupported)
        }
    }

    private fun isConnected(result: MethodChannel.Result) {
        val isConnected = stateChangedHandler.state == PeripheralState.connected

        Handler(Looper.getMainLooper()).post {
            result.success(isConnected)
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val hasPermission = flutterBlePeripheralManager!!.requestPermission(activityBinding!!, true)

        Handler(Looper.getMainLooper()).post {
            result.success(hasPermission)
        }
    }

//    private fun sendData(call: MethodCall, result: MethodChannel.Result) {
//        Log.i(tag, "Try send data: ${call.arguments}")
//
//        (call.arguments as? ByteArray)?.let { data ->
//            flutterBlePeripheralManager!!.send(data)
//            Log.i(tag, "Send data: $data")
//            Handler(Looper.getMainLooper()).post { result.success(null) }
//        } ?: Handler(Looper.getMainLooper()).post {
//            Log.i(tag, "Send data error")
//            result.error("122", "send data", null)
//        }
//    }

    private var pendingResultForPermission: MethodChannel.Result? = null
    private var call: MethodCall? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == FlutterBlePeripheralManager.REQUEST_PERMISSION_BT) {
            for (i in permissions.indices) {
                val permission = permissions[i]
                val grantResult = grantResults[i]
                if (permission == Manifest.permission.BLUETOOTH_CONNECT || permission == Manifest.permission.BLUETOOTH_ADVERTISE || permission == Manifest.permission.ACCESS_FINE_LOCATION || permission == Manifest.permission.ACCESS_COARSE_LOCATION) {
                    if (grantResult == PackageManager.PERMISSION_GRANTED) {
                        if (call != null && pendingResultForPermission != null && activityBinding != null) {
                            flutterBlePeripheralManager?.enableBluetooth(call!!, pendingResultForPermission!!, activityBinding!! )
                            return true
                        }

                    }
                }
            }
        }
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener { requestCode, resultCode, _ ->
            when (requestCode) {
                FlutterBlePeripheralManager.REQUEST_ENABLE_BT -> {

                    if (flutterBlePeripheralManager?.pendingResultForActivityResult != null) {
                        flutterBlePeripheralManager!!.pendingResultForActivityResult!!.success(resultCode == Activity.RESULT_OK)
                        flutterBlePeripheralManager?.pendingResultForActivityResult = null
                    }
                    flutterBlePeripheralManager!!.intent = null
                    return@addActivityResultListener true
                }
//                REQUEST_DISCOVERABLE_BLUETOOTH -> {
//                    pendingResultForActivityResult.success(if (resultCode === 0) -1 else resultCode)
//                    return@addActivityResultListener true
//                }
                else -> return@addActivityResultListener false
            }
        }
        activityBinding = binding
        val initialState = checkBluetoothState(false)
        if (initialState != null) {
            stateChangedHandler.publishPeripheralState(initialState)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }
}