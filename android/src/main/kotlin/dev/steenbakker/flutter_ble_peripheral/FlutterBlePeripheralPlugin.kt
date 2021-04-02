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

  // TODO: Add different functions
  // TODO: Add permission check
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when (call.method) {
      "start" -> startPeripheral(call, result)
      "stop" -> stopPeripheral(result)
      "isAdvertising" -> result.success(peripheral.isAdvertising())
//      "isTransmissionSupported" -> isTransmissionSupported(result)
      else -> result.notImplemented()
    }
  }

  @Suppress("UNCHECKED_CAST")
  private fun startPeripheral(call: MethodCall, result: MethodChannel.Result) {
    if (call.arguments !is Map<*, *>) {
      throw IllegalArgumentException("Arguments are not a map! " + call.arguments)
    }

    val arguments = call.arguments as Map<String, Any>
    val advertiseData = Data(
            arguments["uuid"] as String,
            arguments["transmissionPowerIncluded"] as Boolean?,
            arguments["manufacturerId"] as Int?,
            arguments["manufacturerData"] as List<Int>?,
            arguments["serviceDataUuid"] as String?,
            arguments["serviceData"] as List<Int>?,
            arguments["includeDeviceName"] as Boolean?
    )
    
    val advertiseSettings: AdvertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode((arguments["advertiseMode"] as Int?) ?: AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(arguments["connectable"] as Boolean? ?: false)
            .setTimeout(arguments["timeout"] as Int? ?: 400) 
            .setTxPowerLevel(arguments["txPowerLevel"] as Int? ?: AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()

    if (peripheral.start(advertiseData, advertiseSettings)) {
      result.success(null)
    } else {
      result.error("FlutterBlePeripheral", "Failed to start advertising", null)
    }
  }

  private fun stopPeripheral(result: MethodChannel.Result) {
    if (peripheral.stop()) {
      result.success(null)
    } else {
      result.error("FlutterBlePeripheral", "Failed to stop advertising", null)
    }
  }

  // TODO: Fix listeners
  override fun onListen(event: Any?, eventSink: EventChannel.EventSink) {
    this.eventSink = eventSink
  }

  override fun onCancel(event: Any?) {
    this.eventSink = null
  }
}

