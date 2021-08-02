/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlutterBlePeripheralPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var methodChannel: MethodChannel? = null
    private var peripheral: Peripheral = Peripheral()
    private var context: Context? = null

    private var eventSink: EventChannel.EventSink? = null
    private var advertiseCallback: (Boolean) -> Unit = { isAdvertising ->
        eventSink?.success(isAdvertising)
    }

    private val stateChangedHandler = StateChangedHandler()
    private val dataReceivedHandler = DataReceivedHandler()

    /** Plugin registration embedding v2 */
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state"
        )
        methodChannel!!.setMethodCallHandler(this)

        context = flutterPluginBinding.applicationContext

        peripheral.init(context!!)

        stateChangedHandler.register(flutterPluginBinding, peripheral)
        dataReceivedHandler.register(flutterPluginBinding, peripheral)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel!!.setMethodCallHandler(null)
        methodChannel = null
    }

    // TODO: Add permission check
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startPeripheral(call, result)
            "stop" -> stopPeripheral(result)
            "isAdvertising" -> Handler(Looper.getMainLooper()).post {
                result.success(peripheral.isAdvertising())
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
        if (call.arguments !is Map<*, *>) {
            throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
        }

        val arguments = call.arguments as Map<String, Any>
        val advertiseData = Data()
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

        val advertiseSettings: AdvertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode(advertiseData.advertiseMode)
            .setConnectable(advertiseData.connectable)
            .setTimeout(advertiseData.timeout)
            .setTxPowerLevel(advertiseData.txPowerLevel)
            .build()

        peripheral.start(advertiseData, advertiseSettings, advertiseCallback)

        Handler(Looper.getMainLooper()).post {
            result.success(null)

        }
    }

    private fun stopPeripheral(result: MethodChannel.Result) {
        peripheral.stop()
        Handler(Looper.getMainLooper()).post {
            result.success(null)

        }
    }

    private fun isSupported(result: MethodChannel.Result) {
        if (context != null) {
            val pm: PackageManager = context!!.packageManager
            Handler(Looper.getMainLooper()).post {
                result.success(pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE))

            }
        } else {
            Handler(Looper.getMainLooper()).post {
                result.error("isSupported", "No context available", null)
            }
        }
    }

    private fun isConnected(result: MethodChannel.Result) {
        Handler(Looper.getMainLooper()).post {
            result.success(peripheral.isConnected())

        }
    }

    private fun sendData(call: MethodCall, result: MethodChannel.Result) {
        Log.i("SEND_DATA_TRY", call.arguments?.toString() ?: "No data")
        (call.arguments as? ByteArray)?.let { data ->
            peripheral.send(data)
            Log.i("SEND_DATA", data.toString())
        } ?: Handler(Looper.getMainLooper()).post {
            result.error("122", "send data", null)
        }
    }
}

class StateChangedHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    fun register(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding, peripheral: Peripheral) {
        val eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state_changed"
        )

        eventChannel.setStreamHandler(this)

        peripheral.onStateChanged = { state ->
            val event = when (state) {
                PeripheralState.idle -> Constants.peripheralStateIdle
                PeripheralState.unauthorized -> Constants.peripheralStateUnauthorized
                PeripheralState.unsupported -> Constants.peripheralStateUnsupported
                PeripheralState.advertising -> Constants.peripheralStateAdvertising
                PeripheralState.connected -> Constants.peripheralStateConnected
            }

            Handler(Looper.getMainLooper()).post {
                eventSink?.success(event)
            }
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}

class DataReceivedHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    fun register(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding, peripheral: Peripheral) {
        val eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_data_received"
        )

        eventChannel.setStreamHandler(this)

        peripheral.onDataReceived = {
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(it)
            }
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}
