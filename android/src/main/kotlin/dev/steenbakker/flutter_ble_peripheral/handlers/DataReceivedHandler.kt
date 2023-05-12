package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.FlutterBlePeripheralManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class DataReceivedHandler(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    private val eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state_changed"
    )

    init {
        eventChannel.setStreamHandler(this)
    }

    fun publishData(data: ByteArray) {
        Handler(Looper.getMainLooper()).post {
            eventSink!!.success(data)
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}