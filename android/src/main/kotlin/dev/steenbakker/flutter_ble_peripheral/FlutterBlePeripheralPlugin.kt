/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.app.Activity
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.PeriodicAdvertisingParameters
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.Settings
import androidx.core.app.ActivityCompat
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
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

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(
                flutterPluginBinding.binaryMessenger,
                "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel?.setMethodCallHandler(this)


        stateChangedHandler = StateChangedHandler(flutterPluginBinding)
        stateChangedHandler.publishPeripheralState(PeripheralState.poweredOff)
        flutterBlePeripheralManager = FlutterBlePeripheralManager(flutterPluginBinding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        flutterBlePeripheralManager = null
        context = null

    }

    private fun enableBluetooth(call: MethodCall, result: MethodChannel.Result, requestPermission: Boolean) {
        if (activityBinding != null) {
            this.call = call
            this.pendingResultForPermission = result
            flutterBlePeripheralManager!!.checkAndEnableBluetooth(call, result, activityBinding!!, requestPermission)
        } else {
            result.error("No activity", "FlutterBlePeripheral is not correctly initialized", "null")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null || context == null) {
            result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", "null")
        }

        if (call.method == "start" ||
            call.method == "stop") {
            if (flutterBlePeripheralManager!!.mBluetoothManager == null) {
                stateChangedHandler.publishPeripheralState(PeripheralState.unsupported)
                result.error(
                    PeripheralState.unsupported.name,
                    null,
                    PeripheralState.unsupported
                )
                return
            }

            // Can't check whether ble is turned off or not supported, see https://stackoverflow.com/questions/32092902/why-ismultipleadvertisementsupported-returns-false-when-getbluetoothleadverti
            // !bluetoothAdapter.isMultipleAdvertisementSupported
            if (flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.bluetoothLeAdvertiser == null) {
                stateChangedHandler.publishPeripheralState(PeripheralState.poweredOff)
                result.error(
                    PeripheralState.poweredOff.name,
                    null,
                    PeripheralState.poweredOff
                )
                return
            } else {
                flutterBlePeripheralManager!!.mBluetoothLeAdvertiser ?: flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.bluetoothLeAdvertiser
            }
        }
        flutterBlePeripheralManager!!.mBluetoothLeAdvertiser = flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.bluetoothLeAdvertiser

        val arguments = call.arguments as? Map<*, *>
        val requestPermission = arguments?.get("requestPermission") as Boolean? ?: true

        when (call.method) {
            "start" -> startPeripheral(call, result)
            "stop" -> stopPeripheral(result)
            "isAdvertising" -> Handler(Looper.getMainLooper()).post {
                result.success(stateChangedHandler.state == PeripheralState.advertising)
            }
            "isSupported" -> isSupported(result, context!!)
            "isConnected" -> isConnected(result)
            "hasPermissions" -> Handler(Looper.getMainLooper()).post {
                result.success(flutterBlePeripheralManager!!.checkPermissions(activityBinding!!, false))
            }
            "requestPermissions" -> Handler(Looper.getMainLooper()).post {
                this.pendingResultForPermission = result
                val response = flutterBlePeripheralManager!!.checkPermissions(activityBinding!!, true)
                if (response.isEmpty()) {
                    result.success(response)
                    this.pendingResultForPermission = null
                }
            }
            "enableBluetooth" -> enableBluetooth(call, result, requestPermission)
            "openAppSettings" -> Handler(Looper.getMainLooper()).post {
                activityBinding!!.activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context!!.packageName, null)))
                result.success(null)
            }
            "openBluetoothSettings" -> Handler(Looper.getMainLooper()).post {
                activityBinding!!.activity.startActivity( Intent(Settings.ACTION_BLUETOOTH_SETTINGS), null)
                result.success(null)
            }
//                  "sendData" -> sendData(call, result)
            else -> Handler(Looper.getMainLooper()).post {
                result.notImplemented()
            }
        }


    }

    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {

        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<*, *>

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
            Log.i(tag, "Is BLE connected: $isConnected")
            result.success(isConnected)
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

    var pendingResultForPermission: MethodChannel.Result? = null
    private var call: MethodCall? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == FlutterBlePeripheralManager.REQUEST_PERMISSION_BT) {
            val results = mutableMapOf<String, Int>()

            for (i in permissions.indices) {
                val permission = permissions[i]
                val grantResult = grantResults[i]
                if (grantResult == PackageManager.PERMISSION_GRANTED) {
                    results[permission] = PermissionState.Granted.ordinal

                    // If asked to turn bluetooth on, turn it on
                    if (flutterBlePeripheralManager?.pendingResultForActivityResult != null && activityBinding != null) {
                        flutterBlePeripheralManager?.enableBluetooth(call!!, flutterBlePeripheralManager?.pendingResultForActivityResult!!, activityBinding!!)
                    }
                } else {
                    if (ActivityCompat.shouldShowRequestPermissionRationale(activityBinding!!.activity, permission)) {
                        results[permission] = PermissionState.Denied.ordinal
                    } else {
                        results[permission] = PermissionState.PermanentlyDenied.ordinal
                    }
                }
            }
            pendingResultForPermission!!.success(results)
        }
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener { requestCode, resultCode, _ ->
            when (requestCode) {
                FlutterBlePeripheralManager.REQUEST_ENABLE_BT -> {
                    Activity.RESULT_CANCELED
                    if (flutterBlePeripheralManager?.pendingResultForActivityResult != null) {
                        flutterBlePeripheralManager!!.pendingResultForActivityResult!!.success(resultCode == Activity.RESULT_OK)
                        flutterBlePeripheralManager?.pendingResultForActivityResult = null
                    }

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