/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
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
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.exceptions.PermissionNotFoundException
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.RequestPermissionsHandler
import dev.steenbakker.flutter_ble_peripheral.models.*
import dev.steenbakker.flutter_ble_peripheral.models.State.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*
import kotlin.properties.Delegates


class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        const val REQUEST_ENABLE_BT = 4
        const val TAG: String = "FlutterBlePeripheralPlugin"
    }

    private var methodChannel: MethodChannel? = null
    private var flutterBlePeripheralManager: FlutterBlePeripheralManager? = null
    private var gattServerManager: GattServerManager? = null

    private var isSupported: Boolean by Delegates.notNull()
    private lateinit var stateChangedHandler: StateChangedHandler
    private var requestPermissionsHandler: RequestPermissionsHandler? = null

    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResultForActivityResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(
                flutterPluginBinding.binaryMessenger,
                "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel!!.setMethodCallHandler(this)

        val context : Context = flutterPluginBinding.applicationContext
        isSupported = context.packageManager!!.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
        stateChangedHandler = StateChangedHandler(flutterPluginBinding)
        val dataHandler = DataReceivedHandler(flutterPluginBinding)
        val mtuHandler = MtuChangedHandler(flutterPluginBinding)
        flutterBlePeripheralManager = FlutterBlePeripheralManager(stateChangedHandler, context)
        gattServerManager = GattServerManager(flutterBlePeripheralManager!!, stateChangedHandler, dataHandler, mtuHandler, context)

        stateChangedHandler.publishPeripheralState(
            if (!isSupported) PeripheralState.unsupported
            else if (!flutterBlePeripheralManager!!.isEnabled()) PeripheralState.poweredOff
            else PeripheralState.idle
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        flutterBlePeripheralManager = null
        gattServerManager?.dispose()
        gattServerManager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null || activityBinding == null) {
            result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", null)
            return
        }

        if (call.method == "start" || call.method == "stop") {
            requestPermissionsHandler!!.requestPermission {
                if (it == Granted || it == Ready) {
                    onMethodCall(call, result)
                } else {
                    result.error("No Permission",
                        "Permissions not granted for call to $${call.method} method",
                        null
                    )
                }
            }
            return
        }

        try {
            when (call.method) {
                "start" -> startPeripheral(call, result)
                "stop" -> flutterBlePeripheralManager!!.stop(result)
                "enableBluetooth" -> enableBluetooth(call.arguments as Boolean, result)
                "requestPermission" -> Handler(Looper.getMainLooper()).post {
                    requestPermissionsHandler!!.requestPermission {
                        result.success(it.ordinal)
                    }
                }
                "hasPermission" -> Handler(Looper.getMainLooper()).post {
                    result.success(RequestPermissionsHandler.hasPermissions(activityBinding!!.activity).ordinal)
                }
                "openAppSettings" -> Handler(Looper.getMainLooper()).post {
                    activityBinding!!.activity.startActivity(Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", activityBinding!!.activity.packageName, null)
                    ))
                    result.success(null)
                }
                "openBluetoothSettings" -> Handler(Looper.getMainLooper()).post {
                    activityBinding!!.activity.startActivity( Intent(Settings.ACTION_BLUETOOTH_SETTINGS), null)
                    result.success(null)
                }
                "addService" -> addService(call, result)
                "removeService" -> removeService(call, result)
                "read" -> result.success(gattServerManager!!.read(UUID.fromString(call.arguments as String)))
                "write" -> write(call, result)
                else -> Handler(Looper.getMainLooper()).post {
                    result.notImplemented()
                }
            }
        } catch (e: PeripheralException) {
            stateChangedHandler.publishPeripheralState(e.state)
            result.error(
                    e.state.name,
                    e.localizedMessage,
                    e.stackTrace
            )
        } catch (e: PermissionNotFoundException) {
            result.error(
                    "No Permission",
                    "No permission for ${e.message} Please ask runtime permission.",
                    "Manifest.permission.${e.message}"
            )
        } catch (e: Throwable) { //TODO: tirar e apanhar outras exceções que ha por aí
            result.error("random native exception", e.message, null /* e.getStackTrace().joinToString() */)
        }
    }

    /**
     * Enables bluetooth with a dialog or without.
     */
    private fun enableBluetooth(askUser: Boolean, result: MethodChannel.Result) {
        if (activityBinding == null) {
            result.error("No activity", "FlutterBlePeripheral is not correctly initialized", "null")
        } else if (flutterBlePeripheralManager!!.isEnabled()) {
            result.success(true)
        } else {
            requestPermissionsHandler!!.requestPermission {
                if (askUser && pendingResultForActivityResult == null) { //TODO: separate if statement and add error checking
                    pendingResultForActivityResult = result

                    ActivityCompat.startActivityForResult(
                        activityBinding!!.activity,
                        Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                        REQUEST_ENABLE_BT,
                        null
                    )
                } else {
                    flutterBlePeripheralManager!!.enableBluetooth(result)
                }
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

        //TODO: switch advertiseData for advertiseResponseData below???

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

            flutterBlePeripheralManager!!.startSet(advertiseData.build(), advertiseSettingsSet.build(), advertiseResponseData?.build(), periodicAdvertiseData?.build(), periodicAdvertiseDataSettings?.build(),
                    maxExtendedAdvertisingEvents, duration, result)
        } else {
            // Setup the advertiseSettings
            val advertiseSettings: AdvertiseSettings.Builder = AdvertiseSettings.Builder()

            (arguments["advertiseMode"] as Int?)?.let { advertiseSettings.setAdvertiseMode(it) }
            (arguments["connectable"] as Boolean?)?.let { advertiseSettings.setConnectable(it) }
            (arguments["timeout"] as Int?)?.let { advertiseSettings.setTimeout(it) }
            (arguments["txPowerLevel"] as Int?)?.let { advertiseSettings.setTxPowerLevel(it) }

            flutterBlePeripheralManager!!.start(advertiseData.build(), advertiseSettings.build(), advertiseResponseData?.build(), result)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun addService(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val service = ServiceDescription(call.arguments as Map<String, Any>)
        val chars : Map<BluetoothGattCharacteristic, ByteArray> = service.characteristics.associateBy({
            val ans = BluetoothGattCharacteristic(it.uuid, it.properties(), it.permissions())
            if (it.notify || it.indicate) {
                val descriptor = BluetoothGattDescriptor(
                    GattServerManager.CLIENT_CHARACTERISTIC_CONFIG,
                    BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ)
                ans.addDescriptor(descriptor)
            }
            ans
        }, { it.value })

        gattServerManager!!.addService(service.uuid, chars, result)
    }

    private fun removeService(call: MethodCall, result: MethodChannel.Result) {
        val uuid = call.arguments as String
        result.success(gattServerManager!!.removeService(UUID.fromString(uuid)))
    }

    @Suppress("UNCHECKED_CAST")
    private fun write(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<String,Any>
        val uuid = arguments["characteristic"] as String
        val data = arguments["data"] as ByteArray
        gattServerManager!!.write(UUID.fromString(uuid), data, result)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addRequestPermissionsResultListener(requestPermissionsHandler!!)
        binding.addActivityResultListener { requestCode, resultCode, _ ->
            when (requestCode) {
                REQUEST_ENABLE_BT -> {
                    //TODO: error checking
                    //if (resultCode != Activity.RESULT_OK) ...

                    if (pendingResultForActivityResult != null) { //TODO: error checking
                        pendingResultForActivityResult!!.success(resultCode == Activity.RESULT_OK)
                        pendingResultForActivityResult = null
                    }
                    return@addActivityResultListener true
                }
                else -> return@addActivityResultListener false
            }
        }
        activityBinding = binding
        if (requestPermissionsHandler == null) {
            requestPermissionsHandler =  RequestPermissionsHandler(binding.activity)
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
        requestPermissionsHandler = null
    }
}