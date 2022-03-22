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
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.exceptions.PermissionNotFoundException
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.*
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*


class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private var methodChannel: MethodChannel? = null
    private val tag: String = "flutter_ble_peripheral"
    private var flutterBlePeripheralManager: FlutterBlePeripheralManager? = null

    private lateinit var mtuChangedHandler: MtuChangedHandler
    private lateinit var stateChangedHandler: StateChangedHandler
//    private val dataReceivedHandler = DataReceivedHandler()
    private var context: Context? = null

    private val requestEnableBt = 4

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel?.setMethodCallHandler(this)

        stateChangedHandler = StateChangedHandler(flutterPluginBinding)
        stateChangedHandler.publishPeripheralState(PeripheralState.poweredOff)


        try {
            flutterBlePeripheralManager = FlutterBlePeripheralManager(flutterPluginBinding.applicationContext, stateChangedHandler)
        } catch (e: PeripheralException) {
            stateChangedHandler.publishPeripheralState(e.state)
            Log.e(tag, e.state.name)
            return
        }

        mtuChangedHandler = MtuChangedHandler(flutterPluginBinding, flutterBlePeripheralManager!!)


//        dataReceivedHandler.register(flutterPluginBinding, flutterBlePeripheralManager)




    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        flutterBlePeripheralManager = null
        context = null

    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null || context == null) {
            result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", "null")
        }
        when (call.method) {
            "start" -> startPeripheral(call, result)
            "stop" -> stopPeripheral(result)
            "isAdvertising" -> Handler(Looper.getMainLooper()).post {
                result.success(flutterBlePeripheralManager?.isAdvertising())
            }
            "isSupported" -> isSupported(result, context!!)
            "isConnected" -> isConnected(result)
            "sendData" -> sendData(call, result)
            "enableBluetooth" -> enableBluetooth(call, result)
            else -> Handler(Looper.getMainLooper()).post {
                result.notImplemented()
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {
        try {
            hasPermissions(context!!)
        } catch (e: Exception) {
            result.error(
                "No Permission",
                "No permission for ${e.message} Please ask runtime permission.",
                "Manifest.permission.${e.message}"
            )
            return
        }

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

            flutterBlePeripheralManager!!.startSet(advertiseData.build(), advertiseSettingsSet.build(),
                result, advertiseResponseData?.build(), periodicAdvertiseData?.build(), periodicAdvertiseDataSettings?.build(),
                maxExtendedAdvertisingEvents, duration)
        } else {
            // Setup the advertiseSettings
            val advertiseSettings: AdvertiseSettings.Builder = AdvertiseSettings.Builder()

            (arguments["advertiseMode"] as Int?)?.let { advertiseSettings.setAdvertiseMode(it) }
            (arguments["connectable"] as Boolean?)?.let { advertiseSettings.setConnectable(it) }
            (arguments["timeout"] as Int?)?.let { advertiseSettings.setTimeout(it) }
            (arguments["txPowerLevel"] as Int?)?.let { advertiseSettings.setTxPowerLevel(it) }

            flutterBlePeripheralManager!!.start(advertiseData.build(), advertiseSettings.build(), result, advertiseResponseData?.build())
        }

//
//        Handler(Looper.getMainLooper()).post {
//            Log.i(tag, "Start advertise: $advertiseData")
//            result.success(null)
//        }
    }

    private fun stopPeripheral(result: MethodChannel.Result) {
//        try {
//            hasPermissions()
//        } catch (e: Exception) {
//            result.error(
//                "No Permission",
//                "No permission for ${e.message} Please ask runtime permission.",
//                "Manifest.permission.${e.message}"
//            )
//            return
//        }

        flutterBlePeripheralManager!!.stop(result)

        Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Stop advertise")
            result.success(null)
        }
    }

    private fun isSupported(result: MethodChannel.Result, context: Context) {
//            val pm: PackageManager = context!!.packageManager
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

    private fun sendData(call: MethodCall, result: MethodChannel.Result) {
        Log.i(tag, "Try send data: ${call.arguments}")

        (call.arguments as? ByteArray)?.let { data ->
            flutterBlePeripheralManager!!.send(data)
            Log.i(tag, "Send data: $data")
            Handler(Looper.getMainLooper()).post { result.success(null) }
        } ?: Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Send data error")
            result.error("122", "send data", null)
        }
    }

    private fun hasPermissions(context: Context): Boolean {
        // Required for API > 31
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!hasBluetoothAdvertisePermission(context)) {
                throw PermissionNotFoundException("BLUETOOTH_ADVERTISE")
            }
//            if (!hasBluetoothConnectPermission(context)) {
//                throw PermissionNotFoundException("BLUETOOTH_CONNECT")
//            }
//            if (!hasBluetoothScanPermission(context)) {
//                throw PermissionNotFoundException("BLUETOOTH_SCAN")
//            }

            // Required for API > 28
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (!hasLocationFinePermission(context)) {
                throw PermissionNotFoundException("ACCESS_FINE_LOCATION")
            }

            // Required for API < 28
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M){
            if (!hasLocationCoarsePermission(context)) {
                throw PermissionNotFoundException("ACCESS_COARSE_LOCATION")
            }
        }
        return true

    }

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

    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothScanPermission(context: Context): Boolean {
        return (context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
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

    private var activityBinding: ActivityPluginBinding? = null



    private fun enableBluetooth(call: MethodCall, result: MethodChannel.Result) {
        if (activityBinding != null) {
            flutterBlePeripheralManager!!.enableBluetooth(call, result, activityBinding!!)
        } else {
            result.error("No activity", null, null)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addActivityResultListener { requestCode, resultCode, data ->
            when (requestCode) {
                requestEnableBt -> {
                    // @TODO - used underlying value of `Activity.RESULT_CANCELED` since we tend to use `androidx` in which I were not able to find the constant.
                    if (flutterBlePeripheralManager?.pendingResultForActivityResult != null) {
                        flutterBlePeripheralManager!!.pendingResultForActivityResult!!.success(resultCode == Activity.RESULT_OK)
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