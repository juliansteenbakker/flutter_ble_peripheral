/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.exceptions.PermissionNotFoundException
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralData
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private val tag: String = "flutter_ble_peripheral"
    private var methodChannel: MethodChannel? = null
    private var flutterBlePeripheralManager: FlutterBlePeripheralManager = FlutterBlePeripheralManager()
    private var context: Context? = null

    private val mtuChangedHandler = MtuChangedHandler()
    private val stateChangedHandler = StateChangedHandler()
    private val dataReceivedHandler = DataReceivedHandler()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel?.setMethodCallHandler(this)

        context = flutterPluginBinding.applicationContext

        try {
            flutterBlePeripheralManager.init(flutterPluginBinding.applicationContext)
        } catch (e: PeripheralException) {
            flutterBlePeripheralManager.handlePeripheralException(e, null)
            return
        }

        mtuChangedHandler.register(flutterPluginBinding, flutterBlePeripheralManager)
        stateChangedHandler.register(flutterPluginBinding, flutterBlePeripheralManager)
        dataReceivedHandler.register(flutterPluginBinding, flutterBlePeripheralManager)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startPeripheral(call, result)
            "stop" -> stopPeripheral(result)
            "isAdvertising" -> Handler(Looper.getMainLooper()).post {
                result.success(flutterBlePeripheralManager.isAdvertising())
            }
            "isSupported" -> isSupported(result)
            "isConnected" -> isConnected(result)
            "sendData" -> sendData(call, result)
            else -> Handler(Looper.getMainLooper()).post {
                result.notImplemented()
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {
        try {
            hasPermissions()
        } catch (e: Exception) {
            result.error(
                    "No Permission",
                    "No permission for ${e.message} Please ask runtime permission.",
                    "Manifest.permission.${e.message}")
            return
        }

        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<String, Any>
        val advertiseData = PeripheralData()
        (arguments["uuid"] as String?)?.let { advertiseData.uuid = it }
        (arguments["manufacturerId"] as Int?)?.let { advertiseData.manufacturerId = it }
        (arguments["manufacturerData"] as List<Int>?)?.let { advertiseData.manufacturerData = it }
        (arguments["serviceDataUuid"] as String?)?.let { advertiseData.serviceDataUuid = it }
        (arguments["serviceData"] as List<Int>?)?.let { advertiseData.serviceData = it }
        (arguments["includeDeviceName"] as Boolean?)?.let { advertiseData.includeDeviceName = it }
        (arguments["transmissionPowerIncluded"] as Boolean?)?.let {
            advertiseData.includeTxPowerLevel = it
        }
        (arguments["advertiseMode"] as Int?)?.let { advertiseData.advertiseMode = it }
        (arguments["connectable"] as Boolean?)?.let { advertiseData.connectable = it }
        (arguments["timeout"] as Int?)?.let { advertiseData.timeout = it }
        (arguments["txPowerLevel"] as Int?)?.let { advertiseData.txPowerLevel = it }

        flutterBlePeripheralManager.start(advertiseData, result)

        Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Start advertise: $advertiseData")
            result.success(null)
        }
    }

    private fun stopPeripheral(result: MethodChannel.Result) {
        try {
            hasPermissions()
        } catch (e: Exception) {
            result.error(
                    "No Permission",
                    "No permission for ${e.message} Please ask runtime permission.",
                    "Manifest.permission.${e.message}")
            return
        }

        flutterBlePeripheralManager.stop(result)

        Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Stop advertise")
            result.success(null)
        }
    }

    private fun isSupported(result: MethodChannel.Result) {
        if (context != null) {
            val pm: PackageManager = context!!.packageManager
            val isSupported = pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)

            Handler(Looper.getMainLooper()).post {
                result.success(isSupported)
            }

        } else {
            Handler(Looper.getMainLooper()).post {
                result.error("isSupported", "No context available", null)
            }
        }
    }

    private fun isConnected(result: MethodChannel.Result) {
        val isConnected = flutterBlePeripheralManager.isConnected()

        Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Is BLE connected: $isConnected")
            result.success(isConnected)
        }
    }

    private fun sendData(call: MethodCall, result: MethodChannel.Result) {
        Log.i(tag, "Try send data: ${call.arguments}")

        (call.arguments as? ByteArray)?.let { data ->
            flutterBlePeripheralManager.send(data)
            Log.i(tag, "Send data: $data")
            Handler(Looper.getMainLooper()).post { result.success(null) }
        } ?: Handler(Looper.getMainLooper()).post {
            Log.i(tag, "Send data error")
            result.error("122", "send data", null)
        }
    }

    private fun hasPermissions(): Boolean{
        // Required for API > 31
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!hasBluetoothAdvertisePermission()) {
                throw PermissionNotFoundException("BLUETOOTH_ADVERTISE")
            }
            if (!hasBluetoothConnectPermission()) {
                throw PermissionNotFoundException("BLUETOOTH_CONNECT")
            }
            if (!hasBluetoothScanPermission()) {
                throw PermissionNotFoundException("BLUETOOTH_SCAN")
            }

            // Required for API > 28
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (!hasLocationFinePermission()) {
                throw PermissionNotFoundException("ACCESS_FINE_LOCATION")
            }

            // Required for API < 28
        } else {
            if (!hasLocationCoarsePermission()) {
                throw PermissionNotFoundException("ACCESS_COARSE_LOCATION")
            }
        }
        return true

    }

    // Permissions for Bluetooth API > 31
    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothAdvertisePermission(): Boolean {
        return (ContextCompat.checkSelfPermission(context!!, Manifest.permission.BLUETOOTH_ADVERTISE)
                == PackageManager.PERMISSION_GRANTED)
    }


    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothConnectPermission(): Boolean {
        return (ContextCompat.checkSelfPermission(context!!, Manifest.permission.BLUETOOTH_CONNECT)
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothScanPermission(): Boolean {
        return (ContextCompat.checkSelfPermission(context!!, Manifest.permission.BLUETOOTH_SCAN)
                == PackageManager.PERMISSION_GRANTED)
    }

    private fun hasLocationFinePermission(): Boolean {
        return (ContextCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED)
    }

    private fun hasLocationCoarsePermission(): Boolean {
        return (ContextCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED)
    }
}