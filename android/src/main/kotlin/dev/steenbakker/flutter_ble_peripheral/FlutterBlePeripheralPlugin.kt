/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.app.Activity
import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.PeriodicAdvertisingParameters
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.Settings
import androidx.core.app.ActivityCompat
import dev.steenbakker.flutter_ble_peripheral.FlutterBlePeripheralManager.Companion.REQUEST_ENABLE_BT
import dev.steenbakker.flutter_ble_peripheral.FlutterBlePeripheralManager.Companion.REQUEST_PERMISSION_BT
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.SubscriptionChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.PeripheralStateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.*
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.*

/**
 * Flutter plugin entry point for the Flutter BLE Peripheral library.
 *
 * Responsibilities:
 * - Manage the method channel and handle Flutter method calls.
 * - Coordinate Bluetooth LE peripheral operations through [FlutterBlePeripheralManager].
 * - Handle Android runtime permissions and activity results.
 * - Interface with Flutter handlers for state changes, data received, and MTU changes.
 */
class FlutterBlePeripheralPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.ActivityResultListener {

    /** Tag for logging purposes. */
    private val tag: String = "flutter_ble_peripheral"

    /** Method channel used for communication with Flutter. */
    private lateinit var methodChannel: MethodChannel

    /** Handler for broadcasting peripheral state changes to Flutter. */
    private lateinit var peripheralStateChangedHandler: PeripheralStateChangedHandler

    /** Handler for broadcasting received data from centrals to Flutter. */
    private lateinit var dataReceivedHandler: DataReceivedHandler

    /** Handler for broadcasting MTU changes to Flutter. */
    private lateinit var mtuChangedHandler: MtuChangedHandler

    /** Handler for broadcasting TX subscription changes to Flutter. */
    private lateinit var subscriptionChangedHandler: SubscriptionChangedHandler

    /** BLE manager responsible for low-level Bluetooth peripheral operations. */
    private var flutterBlePeripheralManager: FlutterBlePeripheralManager? = null

    /** Plugin context (application context). */
    private var context: Context? = null

    /** Current activity binding, needed for permissions and settings. */
    private var activityBinding: ActivityPluginBinding? = null

    /** Lifecycle callbacks used to refresh the state when the app returns to the foreground. */
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null

    /** Receiver for Bluetooth adapter state changes. */
    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                onBluetoothStateChanged(state)
            }
        }
    }

    private fun onBluetoothStateChanged(state: Int) {
        val peripheralState = when (state) {
            BluetoothAdapter.STATE_OFF, BluetoothAdapter.STATE_TURNING_OFF ->
                PeripheralState.poweredOff

            BluetoothAdapter.STATE_ON -> currentEnabledState()

            // Don't update during transition.
            else -> return
        }
        peripheralStateChangedHandler.publish(peripheralState)
    }

    /** State to report while the adapter is on, based on the granted permissions. */
    private fun currentEnabledState(): PeripheralState {
        val hasPermissions = context?.let {
            flutterBlePeripheralManager?.hasRequiredPermissions(it)
        } ?: false
        return if (hasPermissions) PeripheralState.idle
        else PeripheralState.unauthorized
    }

    /** Publish the state derived from the adapter and the granted permissions. */
    private fun publishCurrentState() {
        val isBluetoothEnabled = flutterBlePeripheralManager?.isBluetoothEnabled() ?: false
        peripheralStateChangedHandler.publish(
            if (isBluetoothEnabled) currentEnabledState()
            else PeripheralState.poweredOff
        )
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.steenbakker.flutter_ble_peripheral/ble_state")
        methodChannel.setMethodCallHandler(this)

        context = flutterPluginBinding.applicationContext
        peripheralStateChangedHandler = PeripheralStateChangedHandler(flutterPluginBinding)
        dataReceivedHandler = DataReceivedHandler(flutterPluginBinding)
        mtuChangedHandler = MtuChangedHandler(flutterPluginBinding)
        subscriptionChangedHandler = SubscriptionChangedHandler(flutterPluginBinding)
        flutterBlePeripheralManager = FlutterBlePeripheralManager(
            flutterPluginBinding.applicationContext,
            peripheralStateChangedHandler,
            dataReceivedHandler,
            mtuChangedHandler,
            subscriptionChangedHandler
        )

        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(bluetoothStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(bluetoothStateReceiver, filter)
        }

        publishCurrentState()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            context?.unregisterReceiver(bluetoothStateReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was not registered.
        }

        methodChannel.setMethodCallHandler(null)
        flutterBlePeripheralManager = null
        context = null
    }
    
    /**
     * Handles all incoming method calls from Flutter.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null || context == null) {
            result.error("Not initialized", "FlutterBlePeripheral is not correctly initialized", null)
            return
        }

        when (call.method) {
            "start" -> handleStart(call, result)
            "stop" -> handleStop(result)
            "isSupported" -> handleIsSupported(result)
            "enableBluetooth" -> handleEnableBluetooth(call, result)
            "requestPermission" -> handleRequestPermission(result)
            "hasPermission" -> handleHasPermission(result)
            "openAppSettings" -> handleOpenAppSettings(result)
            "openBluetoothSettings" -> handleOpenBluetoothSettings(result)
            "isAdvertising" -> handleIsAdvertising(result)
            "isConnected" -> handleIsConnected(result)
            "isSubscribed" -> handleIsSubscribed(result)
            "isBluetoothOn" -> handleIsBluetoothOn(result)
            "sendData" -> handleSendData(call, result)
            else -> handleNotImplemented(result)
        }
    }

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        if (flutterBlePeripheralManager == null) {
            safeResult(result) { result.success(PeripheralBluetoothState.Unsupported.ordinal) }
            return
        }

        val manager = flutterBlePeripheralManager!!

        if (activityBinding == null) {
            result.error("No activity", "Activity is not attached", null)
            return
        }

        manager.ensureBluetoothReady(
            activityBinding!!.activity,
            onReady = {
                startPeripheral(call, result)
            },
            onError = { state ->
                safeResult(result) { result.success(state.ordinal) }
            }
        )
    }

    /**
     * Parses a service uuid from Dart into a [UUID].
     *
     * Accepts the 16 bit ("A1B2"), 32 bit ("A1B2C3D4") and 128 bit forms, like CBUUID
     * does on Apple platforms. Short forms are expanded onto the Bluetooth Base UUID;
     * Android re-encodes those as compact 16 or 32 bit uuid lists on air.
     */
    private fun parseServiceUuid(value: String): UUID {
        val hex = value.replace("-", "")
        return when (hex.length) {
            4 -> UUID.fromString("0000$hex-0000-1000-8000-00805F9B34FB")
            8 -> UUID.fromString("$hex-0000-1000-8000-00805F9B34FB")
            32 -> UUID.fromString(
                    "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
                            "${hex.substring(16, 20)}-${hex.substring(20)}"
            )
            else -> throw IllegalArgumentException("Invalid service uuid: $value")
        }
    }

    /**
     * Adds the service uuids under [prefix] to [builder].
     *
     * When the plural `serviceUuids` is set, the singular `serviceUuid` is not used,
     * matching AdvertiseData.serviceUuids and the Apple implementation.
     */
    private fun addServiceUuids(builder: AdvertiseData.Builder, arguments: Map<*, *>, prefix: String = "") {
        val uuids = arguments["${prefix}serviceUuids"] as List<*>?
        if (!uuids.isNullOrEmpty()) {
            uuids.forEach { value ->
                (value as? String)?.let { builder.addServiceUuid(ParcelUuid(parseServiceUuid(it))) }
            }
        } else {
            (arguments["${prefix}serviceUuid"] as? String)?.let {
                builder.addServiceUuid(ParcelUuid(parseServiceUuid(it)))
            }
        }
    }

    /**
     * Reads a byte payload sent from Dart.
     *
     * The standard method codec only keeps a typed byte array for a `Uint8List`;
     * a `List<int>` arrives as a list of boxed ints, so both have to be accepted.
     */
    private fun readBytes(value: Any?): ByteArray? = when (value) {
        null -> null
        is ByteArray -> value
        is List<*> -> ByteArray(value.size) { (value[it] as Number).toByte() }
        else -> throw IllegalArgumentException("Expected a byte payload, got $value")
    }

    /** Adds the manufacturer data under [prefix] to [builder]. */
    private fun addManufacturerData(builder: AdvertiseData.Builder, arguments: Map<*, *>, prefix: String = "") {
        readBytes(arguments["${prefix}manufacturerData"])?.let { bytes ->
            val id = (arguments["${prefix}manufacturerId"] as Number?)?.toInt()
                    ?: throw IllegalArgumentException("${prefix}manufacturerData needs a ${prefix}manufacturerId")
            builder.addManufacturerData(id, bytes)
        }
    }

    /**
     * The GATT service Dart asked for, or null to advertise without one.
     *
     * The characteristic uuids always come from Dart. They are the contract
     * between the peripheral and the central, so they must never be derived
     * from the service uuid.
     */
    private fun readGattService(arguments: Map<*, *>): GattServiceRequest? {
        val serviceUuid = arguments["gattServiceUuid"] as? String ?: return null
        return GattServiceRequest(
                serviceUuid = parseServiceUuid(serviceUuid),
                txCharacteristicUuid = parseServiceUuid(
                        arguments["gattTxCharacteristicUuid"] as? String
                                ?: throw IllegalArgumentException("gattServiceUuid needs a gattTxCharacteristicUuid")
                ),
                rxCharacteristicUuid = parseServiceUuid(
                        arguments["gattRxCharacteristicUuid"] as? String
                                ?: throw IllegalArgumentException("gattServiceUuid needs a gattRxCharacteristicUuid")
                ),
        )
    }

    /** Adds the service data under [prefix] to [builder]. */
    private fun addServiceData(builder: AdvertiseData.Builder, arguments: Map<*, *>, prefix: String = "") {
        readBytes(arguments["${prefix}serviceData"])?.let { bytes ->
            val uuid = arguments["${prefix}serviceDataUuid"] as String?
                    ?: throw IllegalArgumentException("${prefix}serviceData needs a ${prefix}serviceDataUuid")
            builder.addServiceData(ParcelUuid(parseServiceUuid(uuid)), bytes)
        }
    }

    /** Whether Dart sent anything worth putting in the advertisement under [prefix]. */
    private fun hasAdvertiseData(arguments: Map<*, *>, prefix: String): Boolean =
            arguments["${prefix}manufacturerData"] != null ||
                    arguments["${prefix}serviceData"] != null ||
                    arguments["${prefix}serviceUuid"] != null ||
                    !(arguments["${prefix}serviceUuids"] as List<*>?).isNullOrEmpty() ||
                    arguments["${prefix}serviceSolicitationUuid"] != null ||
                    arguments["${prefix}includeDeviceName"] == true

    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {

        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<*, *>

        // First build main advertise data.
        val advertiseData: AdvertiseData.Builder = AdvertiseData.Builder()
        addManufacturerData(advertiseData, arguments)
        addServiceData(advertiseData, arguments)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            (arguments["serviceSolicitationUuid"] as String?)?.let { advertiseData.addServiceSolicitationUuid(
                    ParcelUuid(parseServiceUuid(it))) }

        addServiceUuids(advertiseData, arguments)
        //TODO: addTransportDiscoveryData
        (arguments["includeDeviceName"] as Boolean?)?.let { advertiseData.setIncludeDeviceName(it) }
        (arguments["includeTxPowerLevel"] as Boolean?)?.let {
            advertiseData.setIncludeTxPowerLevel(it)
        }

        // Build advertise response data if provided
        var advertiseResponseData: AdvertiseData.Builder? = null
        if (hasAdvertiseData(arguments, "response")) {
            advertiseResponseData = AdvertiseData.Builder()
            addManufacturerData(advertiseResponseData, arguments, "response")
            addServiceData(advertiseResponseData, arguments, "response")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                (arguments["responseserviceSolicitationUuid"] as String?)?.let { advertiseResponseData.addServiceSolicitationUuid(
                        ParcelUuid(parseServiceUuid(it))) }

            addServiceUuids(advertiseResponseData, arguments, "response")
            //TODO: addTransportDiscoveryData
            (arguments["responseincludeDeviceName"] as Boolean?)?.let { advertiseResponseData.setIncludeDeviceName(it) }
            (arguments["responseincludeTxPowerLevel"] as Boolean?)?.let {
                advertiseResponseData.setIncludeTxPowerLevel(it)
            }
        }

        // Check if we should use the advertiseSet method instead of advertise
        if (arguments["advertiseSet"] as Boolean? == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {


            val advertiseSettingsSet: AdvertisingSetParameters.Builder = AdvertisingSetParameters.Builder()
            (arguments["setanonymous"] as Boolean?)?.let { advertiseSettingsSet.setAnonymous(it) }
            (arguments["setconnectable"] as Boolean?)?.let { advertiseSettingsSet.setConnectable(it) }
            (arguments["setincludeTxPowerLevel"] as Boolean?)?.let { advertiseSettingsSet.setIncludeTxPower(it) }
            (arguments["setinterval"] as Int?)?.let { advertiseSettingsSet.setInterval(it) }
            (arguments["setlegacyMode"] as Boolean?)?.let { advertiseSettingsSet.setLegacyMode(it) }
            (arguments["setprimaryPhy"] as Int?)?.let { advertiseSettingsSet.setPrimaryPhy(it) }
            (arguments["setscannable"] as Boolean?)?.let { advertiseSettingsSet.setScannable(it) }
            (arguments["setsecondaryPhy"] as Int?)?.let { advertiseSettingsSet.setSecondaryPhy(it) }
            (arguments["settxPowerLevel"] as Int?)?.let { advertiseSettingsSet.setTxPowerLevel(it) }

            var periodicAdvertiseData: AdvertiseData.Builder? = null
            var periodicAdvertiseDataSettings: PeriodicAdvertisingParameters.Builder? = null
            if (hasAdvertiseData(arguments, "periodic")) {
                periodicAdvertiseData = AdvertiseData.Builder()
                periodicAdvertiseDataSettings = PeriodicAdvertisingParameters.Builder()

                addManufacturerData(periodicAdvertiseData, arguments, "periodic")
                addServiceData(periodicAdvertiseData, arguments, "periodic")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    (arguments["periodicserviceSolicitationUuid"] as String?)?.let {
                        periodicAdvertiseData.addServiceSolicitationUuid(
                                ParcelUuid(parseServiceUuid(it))
                        )
                    }

                addServiceUuids(periodicAdvertiseData, arguments, "periodic")
                //TODO: addTransportDiscoveryData
                (arguments["periodicincludeDeviceName"] as Boolean?)?.let {
                    periodicAdvertiseData.setIncludeDeviceName(
                        it
                    )
                }
                (arguments["periodicincludeTxPowerLevel"] as Boolean?)?.let {
                    periodicAdvertiseData.setIncludeTxPowerLevel(it)
                }

                (arguments["periodicsettingsincludeTxPowerLevel"] as Boolean?)?.let {
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

            advertisingSetCallback = PeripheralAdvertisingSetCallback(result, peripheralStateChangedHandler)

            flutterBlePeripheralManager!!.startSet(advertiseData.build(), advertiseSettingsSet.build(), advertiseResponseData?.build(), periodicAdvertiseData?.build(), periodicAdvertiseDataSettings?.build(),
                maxExtendedAdvertisingEvents, duration, advertisingSetCallback!!, readGattService(arguments))
        } else {
            // Setup the advertiseSettings
            val advertiseSettings: AdvertiseSettings.Builder = AdvertiseSettings.Builder()

            (arguments["advertiseMode"] as Int?)?.let { advertiseSettings.setAdvertiseMode(it) }
            (arguments["connectable"] as Boolean?)?.let { advertiseSettings.setConnectable(it) }
            (arguments["timeout"] as Int?)?.let { advertiseSettings.setTimeout(it) }
            (arguments["txPowerLevel"] as Int?)?.let { advertiseSettings.setTxPowerLevel(it) }

            advertisingCallback = PeripheralAdvertisingCallback(result, peripheralStateChangedHandler)

            flutterBlePeripheralManager!!.start(advertiseData.build(), advertiseSettings.build(), advertiseResponseData?.build(), advertisingCallback!!, readGattService(arguments))
        }
    }

    /**
     * Stop BLE scan if running.
     */
    private fun handleStop(result: MethodChannel.Result) {
        if (advertisingCallback != null) {
            flutterBlePeripheralManager?.stop(advertisingCallback!!)
        }

        if (advertisingSetCallback != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ) {
            flutterBlePeripheralManager?.stopSet(advertisingSetCallback!!)
        }

        // stopAdvertising does not call back, so nothing else reports the stop and
        // the state would sit on advertising, the way the Apple side publishes it.
        peripheralStateChangedHandler.publish(PeripheralState.idle)

        safeResult(result) {
            result.success(PeripheralBluetoothState.Ready.ordinal)
        }
    }

    /**
     * Check if device supports Bluetooth feature.
     */
    private fun handleIsSupported(result: MethodChannel.Result) {
        val isSupported = context?.packageManager?.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH)
        safeResult(result) {
            result.success(isSupported)
        }
    }

    private fun handleIsAdvertising(result: MethodChannel.Result) {
        safeResult(result) {
            // A central connecting does not end the advertisement, so both states
            // mean the advertiser is still running.
            val state = peripheralStateChangedHandler.state
            result.success(
                state == PeripheralState.advertising || state == PeripheralState.connected
            )
        }
    }

    private fun handleIsSubscribed(result: MethodChannel.Result) {
        val isSubscribed = flutterBlePeripheralManager?.hasSubscribedDevices() ?: false
        safeResult(result) {
            Log.i(tag, "Is a central subscribed: $isSubscribed")
            result.success(isSubscribed)
        }
    }

    private fun handleIsConnected(result: MethodChannel.Result) {
        val isConnected = flutterBlePeripheralManager?.hasConnectedDevices() ?: false
        safeResult(result) {
            Log.i(tag, "Is BLE connected: $isConnected")
            result.success(isConnected)
        }
    }
    
    private fun handleIsBluetoothOn(result: MethodChannel.Result) {
        safeResult(result) {
            result.success(flutterBlePeripheralManager?.isBluetoothEnabled() ?: false)
        }
    }

    /**
     * Request enabling Bluetooth.
     *
     * @param call Flutter method call with `shouldAsk` argument
     * @param result Method channel result callback
     */
    private fun handleEnableBluetooth(call: MethodCall, result: MethodChannel.Result) {
        if (activityBinding != null) {
            val shouldAsk = call.arguments as Boolean
            val isEnabled = flutterBlePeripheralManager!!.isBluetoothEnabled()
            if (!isEnabled) {
                if (shouldAsk) {
                    flutterBlePeripheralManager!!.enableBluetooth(activityBinding!!.activity) { bluetoothEnabled ->
                        safeResult(result) {
                            result.success(bluetoothEnabled)
                        }
                    }
                    return
                } else {
                    flutterBlePeripheralManager!!.enableBluetooth(activityBinding!!.activity, null)
                }
            }

            safeResult(result) {
                result.success(true)
            }
        } else {
            safeResult(result) {
                result.error("No activity", "FlutterBlePeripheral is not correctly initialized", "null")
            }
        }
    }

    /**
     * Request runtime Bluetooth permissions.
     */
    private fun handleRequestPermission(result: MethodChannel.Result) {
        val state = flutterBlePeripheralManager!!.requestPermission(activityBinding!!.activity) { state ->
            safeResult(result) {
                result.success(state.ordinal)
            }
        }

        // If already granted, return immediately
        if (state != null) {
            safeResult(result) {
                result.success(state.ordinal)
            }
        }
    }
    
    /**
     * Check if Bluetooth permissions are granted.
     */
    private fun handleHasPermission(result: MethodChannel.Result) {
        val permission = flutterBlePeripheralManager!!
            .requestPermission(activityBinding!!.activity, null)!!
            .ordinal
        safeResult(result) {
            result.success(permission)
        }
    }

    /**
     * Open system app settings for this application.
     */
    private fun handleOpenAppSettings(result: MethodChannel.Result) {
        activityBinding!!.activity.startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context!!.packageName, null)
            )
        )
        safeResult(result) {
            result.success(null)
        }
    }

    /**
     * Open system Bluetooth settings.
     */
    private fun handleOpenBluetoothSettings(result: MethodChannel.Result) {
        activityBinding!!.activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS), null)
        safeResult(result) {
            result.success(null)
        }
    }

    /**
     * Handle unsupported or unknown method calls.
     */
    private fun handleNotImplemented(result: MethodChannel.Result) {
        safeResult(result) {
            result.notImplemented()
        }
    }
    
    /** Active advertising set callback, used for Android O+ advertising. */
    private var advertisingSetCallback: PeripheralAdvertisingSetCallback? = null

    /** Active advertising callback, used for legacy advertising. */
    private var advertisingCallback: PeripheralAdvertisingCallback? = null
    
    private fun handleSendData(call: MethodCall, result: MethodChannel.Result) {
        safeResult(result) {
            val data = call.arguments as? ByteArray
            if (data == null) {
                Log.e(tag, "Send data error: arguments is not ByteArray")
                result.error("INVALID_ARGUMENT", "Data must be a ByteArray", null)
                return@safeResult
            }

            if (flutterBlePeripheralManager == null) {
                Log.e(tag, "Send data error: manager is null")
                result.error("NOT_INITIALIZED", "FlutterBlePeripheralManager is not initialized", null)
                return@safeResult
            }

            Log.i(tag, "Trying to send ${data.size} bytes")
            val success = flutterBlePeripheralManager!!.sendData(data)

            if (success) {
                Log.i(tag, "Data sent successfully")
                result.success(null)
            } else {
                Log.w(tag, "Failed to send data")
                result.error("SEND_FAILED", "Failed to send data. GATT server may not be initialized or no devices connected", null)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_PERMISSION_BT) {
            val activity = activityBinding!!.activity

            var hasAllPermissions = true
            var shouldShowRationale = false

            for (i in permissions.indices) {
                val grantResult = grantResults[i]
                val permission = permissions[i]
                if (grantResult == PackageManager.PERMISSION_DENIED) {
                    hasAllPermissions = false
                    if (ActivityCompat.shouldShowRequestPermissionRationale(
                            activity,
                            permission
                        )
                    ) {
                        shouldShowRationale = true
                    }
                }
            }

            val resultState = when {
                hasAllPermissions -> {
                    flutterBlePeripheralManager?.setPermissionGranted(activity, true)
                    PeripheralBluetoothState.Granted
                }
                shouldShowRationale -> {
                    flutterBlePeripheralManager?.setPermissionGranted(activity, false)
                    PeripheralBluetoothState.Denied
                }
                else -> {
                    flutterBlePeripheralManager?.setPermissionGranted(activity, false)
                    PeripheralBluetoothState.PermanentlyDenied
                }
            }

            flutterBlePeripheralManager?.permissionResultCallback?.invoke(resultState)
            flutterBlePeripheralManager?.permissionResultCallback = null

            publishCurrentState()
        }
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
        activityBinding = binding

        // Detect when the app resumes, so revoked permissions are picked up.
        lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                if (activity == binding.activity) publishCurrentState()
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        }
        binding.activity.application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        lifecycleCallbacks?.let {
            activityBinding?.activity?.application?.unregisterActivityLifecycleCallbacks(it)
        }
        lifecycleCallbacks = null

        flutterBlePeripheralManager?.permissionResultCallback?.invoke(PeripheralBluetoothState.Denied)
        flutterBlePeripheralManager?.permissionResultCallback = null
        activityBinding = null
    }

    /**
     * Handle activity result from Bluetooth enable dialog.
     */
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ): Boolean {
        if (requestCode == REQUEST_ENABLE_BT) {
            flutterBlePeripheralManager?.bluetoothEnabledCallback?.invoke(resultCode == Activity.RESULT_OK)
            flutterBlePeripheralManager?.bluetoothEnabledCallback = null
        }
        return true
    }

    /**
     * Safely executes a [Result] callback on the main thread.
     *
     * Catches exceptions and reports them to Flutter.
     *
     * @param result The result callback to send responses to Flutter
     * @param block The action to perform
     */
    private fun safeResult(result: MethodChannel.Result, block: () -> Unit) {
        Handler(Looper.getMainLooper()).post {
            try {
                block()
            } catch (e: Exception) {
                result.error("UNEXPECTED_ERROR", e.message, null)
            }
        }
    }
}