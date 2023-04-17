/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.Manifest
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
import dev.steenbakker.flutter_ble_peripheral.models.State.*
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.*


class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private val tag: String = "flutter_ble_peripheral"

    private var methodChannel: MethodChannel? = null
    private lateinit var stateChangedHandler: StateChangedHandler

    private var flutterBlePeripheralManager: FlutterBlePeripheralManager? = null
    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.steenbakker.flutter_ble_peripheral/ble_state")
        methodChannel?.setMethodCallHandler(this)

        context = flutterPluginBinding.applicationContext
        stateChangedHandler = StateChangedHandler(flutterPluginBinding)
        flutterBlePeripheralManager = FlutterBlePeripheralManager(flutterPluginBinding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        flutterBlePeripheralManager = null
        context = null

    }

    private fun checkBluetoothState(result: MethodChannel.Result): State {
        if (flutterBlePeripheralManager!!.mBluetoothManager == null || flutterBlePeripheralManager!!.mBluetoothManager?.adapter == null) {
            result.success(Unsupported.ordinal)
            startStopCall = null
            return Unsupported
        } else {
            // Can't check whether ble is turned off or not supported, see https://stackoverflow.com/questions/32092902/why-ismultipleadvertisementsupported-returns-false-when-getbluetoothleadverti
            // !bluetoothAdapter.isMultipleAdvertisementSupported
            flutterBlePeripheralManager!!.mBluetoothLeAdvertiser = flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.bluetoothLeAdvertiser
            val hasPermissions = flutterBlePeripheralManager!!.requestPermission(activityBinding!!.activity, result)
            if (hasPermissions == Granted) {
                if (!flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.isEnabled) {
                    flutterBlePeripheralManager!!.enableBluetooth(true, result, activityBinding!!, true)
                } else {
                    return Ready
                }
            }
            return hasPermissions
        }
    }

    var startStopCall: MethodCall? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null || context == null) {
            result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", null)
        }

        if (call.method == "start" || call.method == "stop") {
            startStopCall = call
            val state = checkBluetoothState(result)
            if (state != Ready) {
                return
            }
        }

        when (call.method) {
            "start" -> startPeripheral(call, result)
            "stop" -> stopPeripheral(result)
            "isSupported" -> isSupported(result, context!!)
            "isAdvertising" -> Handler(Looper.getMainLooper()).post {
                result.success(stateChangedHandler.state == PeripheralState.advertising)
            }
            "isConnected" -> isConnected(result)
            "enableBluetooth" -> enableBluetooth(call, result)
            "requestPermission" -> Handler(Looper.getMainLooper()).post {
                flutterBlePeripheralManager!!.requestPermission(activityBinding!!.activity, result)
            }
            "hasPermission" -> Handler(Looper.getMainLooper()).post {
                result.success(flutterBlePeripheralManager!!.requestPermission(activityBinding!!.activity, null).ordinal)
            }
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

    private fun enableBluetooth(call: MethodCall, result: MethodChannel.Result) {
        if (activityBinding != null) {
            val isEnabled = flutterBlePeripheralManager!!.checkAndEnableBluetooth(call.arguments as Boolean, result, activityBinding!!)
            result.success(isEnabled)
        } else {
            result.error("No activity", "FlutterBlePeripheral is not correctly initialized", "null")
        }
    }

    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {

        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<*, *>

        // First build main advertise data.
        val advertiseData: AdvertiseData.Builder = AdvertiseData.Builder()
        (arguments["manufacturerData"] as ArrayList<*>?)?.let { list -> advertiseData.addManufacturerData((arguments["manufacturerId"] as Int), list.map { (it as Int).toByte() }.toByteArray()) }
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
        if ((arguments["responsemanufacturerData"] as ByteArray?) != null || (arguments["responseserviceDataUuid"] as ByteArray?) != null || (arguments["responseserviceUuid"] as String?) != null) {
            advertiseResponseData = AdvertiseData.Builder()
            (arguments["responsemanufacturerData"] as ByteArray?)?.let { advertiseData.addManufacturerData((arguments["responsemanufacturerId"] as Int), it) }
            (arguments["responseserviceData"] as ByteArray?).let { advertiseData.addServiceData(ParcelUuid(UUID.fromString(arguments["responseserviceDataUuid"] as String)), it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                (arguments["responseserviceSolicitationUuid"] as String?)?.let { advertiseData.addServiceSolicitationUuid(
                        ParcelUuid(UUID.fromString(it))) }

            (arguments["responseserviceUuid"] as String?)?.let { advertiseData.addServiceUuid(ParcelUuid(UUID.fromString(it))) }
            //TODO: addTransportDiscoveryData
            (arguments["responseincludeDeviceName"] as Boolean?)?.let { advertiseData.setIncludeDeviceName(it) }
            (arguments["responsetransmissionPowerIncluded"] as Boolean?)?.let {
                advertiseData.setIncludeTxPowerLevel(it)
            }
        }

        // Check if we should use the advertiseSet method instead of advertise
        if (arguments["advertiseSet"] as Boolean? == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {


            val advertiseSettingsSet: AdvertisingSetParameters.Builder = AdvertisingSetParameters.Builder()
            (arguments["setanonymous"] as Boolean?)?.let { advertiseSettingsSet.setAnonymous(it) }
            (arguments["setconnectable"] as Boolean?)?.let { advertiseSettingsSet.setConnectable(it) }
            (arguments["setsetIncludeTxPower"] as Boolean?)?.let { advertiseSettingsSet.setIncludeTxPower(it) }
            (arguments["setinterval"] as Int?)?.let { advertiseSettingsSet.setInterval(it) }
            (arguments["setlegacyMode"] as Boolean?)?.let { advertiseSettingsSet.setLegacyMode(it) }
            (arguments["setprimaryPhy"] as Int?)?.let { advertiseSettingsSet.setPrimaryPhy(it) }
            (arguments["setscannable"] as Boolean?)?.let { advertiseSettingsSet.setScannable(it) }
            (arguments["setsecondaryPhy"] as Int?)?.let { advertiseSettingsSet.setSecondaryPhy(it) }
            (arguments["settxPowerLevel"] as Int?)?.let { advertiseSettingsSet.setTxPowerLevel(it) }

            var periodicAdvertiseData: AdvertiseData.Builder? = null
            var periodicAdvertiseDataSettings: PeriodicAdvertisingParameters.Builder? = null
            if ((arguments["periodicmanufacturerData"] as ByteArray?) != null || (arguments["periodicServiceDataUuid"] as ByteArray?) != null || (arguments["periodicServiceUuid"] as String?) != null) {
                periodicAdvertiseData = AdvertiseData.Builder()
                periodicAdvertiseDataSettings = PeriodicAdvertisingParameters.Builder()

                (arguments["periodicmanufacturerData"] as ByteArray?)?.let {
                    periodicAdvertiseData.addManufacturerData(
                            (arguments["periodicManufacturerId"] as Int),
                            it
                    )
                }
                (arguments["periodicserviceData"] as ByteArray?).let {
                    periodicAdvertiseData.addServiceData(
                            ParcelUuid(UUID.fromString(arguments["periodicserviceDataUuid"] as String)),
                            it
                    )
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    (arguments["periodicserviceSolicitationUuid"] as String?)?.let {
                        periodicAdvertiseData.addServiceSolicitationUuid(
                                ParcelUuid(UUID.fromString(it))
                        )
                    }

                (arguments["periodicserviceUuid"] as String?)?.let {
                    periodicAdvertiseData.addServiceUuid(
                            ParcelUuid(UUID.fromString(it))
                    )
                }
                //TODO: addTransportDiscoveryData
                (arguments["periodicincludeDeviceName"] as Boolean?)?.let {
                    periodicAdvertiseData.setIncludeDeviceName(
                            it
                    )
                }
                (arguments["periodictransmissionPowerIncluded"] as Boolean?)?.let {
                    periodicAdvertiseData.setIncludeTxPowerLevel(it)
                }

                (arguments["periodicsettingstransmissionPowerIncluded"] as Boolean?)?.let {
                    periodicAdvertiseDataSettings.setIncludeTxPower(it)
                }

                (arguments["periodicsettingsinterval"] as Int?)?.let {
                    periodicAdvertiseDataSettings.setInterval(it)
                }

            }

            var maxExtendedAdvertisingEvents = 0
            var duration = 0
            (arguments["setmaxExtendedAdvertisingEvents"] as Int?)?.let { maxExtendedAdvertisingEvents = it }
            (arguments["setduration"] as Int?)?.let { duration = it }

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
        if (advertisingCallback != null) {
            flutterBlePeripheralManager?.stop(advertisingCallback!!)
        }

        if (advertisingSetCallback != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ) {
            flutterBlePeripheralManager?.stopSet(advertisingSetCallback!!)
        }
        result.success(Ready.ordinal)
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
            var hasAllPermissions = true
            var shouldShowRationale = false
            for (i in permissions.indices) {
                val permission = permissions[i]
                val grantResult = grantResults[i]
                if (permission == Manifest.permission.BLUETOOTH_CONNECT || permission == Manifest.permission.BLUETOOTH_ADVERTISE || permission == Manifest.permission.ACCESS_FINE_LOCATION || permission == Manifest.permission.ACCESS_COARSE_LOCATION) {
                    if (grantResult == PackageManager.PERMISSION_DENIED) {
                        if (ActivityCompat.shouldShowRequestPermissionRationale(activityBinding!!.activity, permission)) {
                            shouldShowRationale = true
                        }
                        hasAllPermissions = false
                    }
                }
            }

            if (shouldShowRationale) {
                flutterBlePeripheralManager?.pendingResultForPermissionResult?.success(State.Denied.ordinal)
            } else if (!flutterBlePeripheralManager!!.mBluetoothManager!!.adapter.isEnabled && startStopCall != null && hasAllPermissions) {
                flutterBlePeripheralManager!!.enableBluetooth(true, flutterBlePeripheralManager?.pendingResultForPermissionResult, activityBinding!!, true)
            } else {
                if (hasAllPermissions) {
                    flutterBlePeripheralManager?.pendingResultForPermissionResult?.success(State.Granted.ordinal)
                } else {
                    flutterBlePeripheralManager?.pendingResultForPermissionResult?.success(State.PermanentlyDenied.ordinal)
                }
                flutterBlePeripheralManager?.pendingResultForPermissionResult = null
            }
        }

        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener { requestCode, resultCode, _ ->
            when (requestCode) {
                FlutterBlePeripheralManager.REQUEST_ENABLE_BT -> {
                    if (flutterBlePeripheralManager?.pendingResultForActivityResult != null) {
                        startStopCall = null
                        flutterBlePeripheralManager!!.pendingResultForActivityResult!!.success(resultCode == Activity.RESULT_OK)
                    } else if (flutterBlePeripheralManager?.pendingResultForPermissionResult != null) {
                        if (resultCode == Activity.RESULT_OK) {
                            if (startStopCall != null) {
                                onMethodCall(startStopCall!!, flutterBlePeripheralManager!!.pendingResultForPermissionResult!!)
                                startStopCall = null
                                flutterBlePeripheralManager?.pendingResultForPermissionResult = null
                            }
                        } else {
                            flutterBlePeripheralManager?.pendingResultForPermissionResult?.success(State.TurnedOff.ordinal)
                        }
                    }
                    flutterBlePeripheralManager?.pendingResultForActivityResult = null
                    return@addActivityResultListener true
                }
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