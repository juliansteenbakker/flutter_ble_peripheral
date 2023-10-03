package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.FlutterBlePeripheralManager
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class MtuChangedHandler(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) : EventChannel.StreamHandler {
    private val TAG = "MtuChangedHandler"

    private var eventSink: EventChannel.EventSink? = null
    private val eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed"
    )

    private var mtu : Int = 23 //default (smallest possible value)

    init {
        eventChannel.setStreamHandler(this)
    }

    fun publishMtu(mtu : Int) {
        if (this.mtu != mtu) {
            Log.i(TAG, mtu.toString())
            this.mtu = mtu
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mtu)
            }
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink) {
        this.eventSink = eventSink
        Handler(Looper.getMainLooper()).post {
            eventSink.success(mtu)
        }
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}