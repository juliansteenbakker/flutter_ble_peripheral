/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.le.AdvertiseSettings
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.*

class FlutterBlePeripheralPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  private var methodChannel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private var peripheral: Peripheral = Peripheral()

  private var eventSink: EventChannel.EventSink? = null
  private var advertiseCallback: (Boolean) -> Unit = { isAdvertising ->
    eventSink?.success(isAdvertising)
  }


  /** Plugin registration embedding v2 */
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.steenbakker.flutter_ble_peripheral/ble_state")
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "dev.steenbakker.flutter_ble_peripheral/ble_event")
    methodChannel!!.setMethodCallHandler(this)
    eventChannel!!.setStreamHandler(this)
    peripheral.init()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel!!.setMethodCallHandler(null)
    methodChannel = null
    eventChannel!!.setStreamHandler(null)
    eventChannel = null
  }
  
  // TODO: Add permission check
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when (call.method) {
      "start" -> startPeripheral(call, result)
      "stop" -> stopPeripheral(result)
      "isAdvertising" -> result.success(peripheral.isAdvertising())
      else -> result.notImplemented()
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
    (arguments["transmissionPowerIncluded"] as Boolean?)?.let { advertiseData.includeTxPowerLevel = it }
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
    result.success(null)
  }

  private fun stopPeripheral(result: MethodChannel.Result) {
    peripheral.stop()
    result.success(null)
  }
  
  override fun onListen(event: Any?, eventSink: EventChannel.EventSink) {
    this.eventSink = eventSink
  }

  override fun onCancel(event: Any?) {
    this.eventSink = null
  }
}

