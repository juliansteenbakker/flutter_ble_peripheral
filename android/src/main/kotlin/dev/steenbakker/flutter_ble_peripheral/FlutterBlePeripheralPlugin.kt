/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.app.Activity
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.PeriodicAdvertisingParameters
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.Settings
import dev.steenbakker.flutter_ble_peripheral.callbacks.ActivityResultCallback
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.exceptions.PermissionNotFoundException
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.callbacks.PermissionCallback
import dev.steenbakker.flutter_ble_peripheral.models.*
import dev.steenbakker.flutter_ble_peripheral.models.State.*
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*


class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        const val TAG: String = "FlutterBlePeripheralPlugin"
    }

    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var methodChannel: MethodChannel? = null
    private var flutterBlePeripheralManager: FlutterBlePeripheralManager? = null

    private var _gattServerManager: GattServerManager? = null
    private val gattServerManager: GattServerManager get() {
        if (_gattServerManager == null) {
            try {
                _gattServerManager = GattServerManager(flutterBlePeripheralManager!!, stateHandler, dataHandler, mtuHandler, activityBinding!!.activity)
            } catch (e: SecurityException) {
                throw PermissionNotFoundException("android.permission.BLUETOOTH_CONNECT")
            }
        }
        return _gattServerManager!!
    }

    private lateinit var stateHandler: StateChangedHandler
    private lateinit var dataHandler: DataReceivedHandler
    private lateinit var mtuHandler: MtuChangedHandler

    private var activityBinding: ActivityPluginBinding? = null
    private var permissionCallback: PermissionCallback? = null
    private var enableBluetoothCallback: ActivityResultCallback? = null


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding

        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel!!.setMethodCallHandler(this)

        stateHandler = StateChangedHandler(flutterPluginBinding)
        dataHandler = DataReceivedHandler(flutterPluginBinding)
        mtuHandler = MtuChangedHandler(flutterPluginBinding)

        flutterBlePeripheralManager = FlutterBlePeripheralManager(stateHandler, flutterPluginBinding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        _gattServerManager?.close()
        _gattServerManager = null
        flutterBlePeripheralManager?.close()
        flutterBlePeripheralManager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (flutterBlePeripheralManager == null || activityBinding == null) {
                result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", null)
                return
            }

            if ((call.method == "start" || call.method == "stop") && PermissionCallback.permissionState(activityBinding!!.activity) != Granted) {
                permissionCallback!!.requestPermission {
                    stateHandler.publishPeripheralState()
                    if (it == Granted) {
                        onMethodCall(call, result)
                    } else {
                        throw PeripheralException(PeripheralState.unauthorized)
                    }
                }
                return
            }

            when (call.method) {
                "start" -> startPeripheral(call, result)
                "stop" -> flutterBlePeripheralManager!!.stop(result)
                "enableBluetooth" -> enableBluetooth(call.arguments as Boolean, result)
                "requestPermission" -> Handler(Looper.getMainLooper()).post {
                    permissionCallback!!.requestPermission {
                        stateHandler.publishPeripheralState()
                        result.success(it.ordinal)
                    }
                }
                "hasPermission" -> Handler(Looper.getMainLooper()).post {
                    result.success(PermissionCallback.permissionState(activityBinding!!.activity).ordinal)
                }
                "openAppSettings" -> Handler(Looper.getMainLooper()).post {
                    activityBinding!!.activity.startActivity(Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", activityBinding!!.activity.packageName, null)
                    ))
                    result.success(null)
                }
                "openBluetoothSettings" -> Handler(Looper.getMainLooper()).post {
                    activityBinding!!.activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS), null)
                    result.success(null)
                }
                "addService" -> addService(call, result)
                "removeService" -> removeService(call, result)
                "read" -> result.success(_gattServerManager?.read(UUID.fromString(call.arguments as String)))
                "write" -> write(call, result)
                "disconnect" -> disconnect(result)
                else -> Handler(Looper.getMainLooper()).post {
                    result.notImplemented()
                }
            }
        } catch (e: PeripheralException) {
            result.error(
                "InvalidState",
                e.localizedMessage,
                e.state.ordinal
            )
        } catch (e: java.lang.IllegalArgumentException) {
            result.error("ArgumentError", e.message, null)
        } catch (e: Throwable) {
            result.error("Native exception", e.message, e.stackTrace.joinToString("\n"))
        }
    }

    /**
     * Enables bluetooth with a dialog or without.
     * result is resolved as true if bluetooth is enabled, false otherwise
     */
    private fun enableBluetooth(askUser: Boolean, result: MethodChannel.Result) {
        if (activityBinding == null) {
            result.error("No activity", "FlutterBlePeripheral is not correctly initialized", null)
        } else if (stateHandler.bluetoothPowered) {
            result.success(true)
        } else {
            permissionCallback!!.requestPermission {
                stateHandler.publishPeripheralState() //update permissions state
                if (askUser) {
                    enableBluetoothCallback!!.enableBluetooth {
                        result.success(it == Activity.RESULT_OK)
                        stateHandler.publishPeripheralState()
                    }
                } else {
                    flutterBlePeripheralManager!!.enableBluetooth(result)
                }
            }
        }
    }

    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {

        //In some versions of android (from my testing, api < 31), ble advertising can occur while bluetooth is off
        //For a matter of consistency, however, I think bluetooth should be required to be on anyway
        if (stateHandler.state != PeripheralState.idle) {
            throw PeripheralException(stateHandler.state)
        }

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

        (arguments["serviceUuid"] as String?)?.let { advertiseData.addServiceUuid(ParcelUuid(UUID.fromString(it))) }
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
        if (arguments["advertiseSet"] as Boolean? == true) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.error("UnsupportedOperation", "AdvertiseSet only supported from API 26 onwards", null)
                return
            }

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

    /**
     * Adds a service to the gatt server if a service with the same uuid doesn't yet exist
     * result is resolved as true if a service is added, false otherwise
     */
    @Suppress("UNCHECKED_CAST")
    private fun addService(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        //TODO: accept 2-byte uuids
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
        gattServerManager.addService(service.uuid, chars, result)
    }

    /**
     * Removes the service with the specified uuid from the gatt server
     * result is resolved as true if such a service existed (and was removed), false otherwise
     */
    private fun removeService(call: MethodCall, result: MethodChannel.Result) {
        val uuid = call.arguments as String
        result.success(_gattServerManager?.removeService(UUID.fromString(uuid)) ?: false)
    }

    /**
     * Writes data to a gatt characteristic and notifies any subscribed devices
     */
    @Suppress("UNCHECKED_CAST")
    private fun write(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<String,Any>
        val uuid = arguments["characteristic"] as String
        val data = arguments["data"] as ByteArray
        gattServerManager.write(UUID.fromString(uuid), data, 0, result)
    }

    /**
     * Disconnects all connected devices
     */
    private fun disconnect(result: MethodChannel.Result) {
        if (_gattServerManager != null)
            _gattServerManager!!.disconnect(result)
        else
            result.success(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        permissionCallback = PermissionCallback(binding)
        enableBluetoothCallback = ActivityResultCallback(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
        permissionCallback = null
        enableBluetoothCallback = null
    }
}