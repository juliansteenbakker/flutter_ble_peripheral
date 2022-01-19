package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.FlutterBlePeripheralManager
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class StateChangedHandler : EventChannel.StreamHandler {
    private val tag: String = "BLE Peripheral state "

    private var eventSink: EventChannel.EventSink? = null

    var state = PeripheralState.idle


    fun register(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding, flutterBlePeripheralManager: FlutterBlePeripheralManager) {
        val eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.steenbakker.flutter_ble_peripheral/ble_state_changed"
        )

        eventChannel.setStreamHandler(this)

        flutterBlePeripheralManager.onStateChanged = { state ->
            send(state)
        }
    }

    private fun send(state: PeripheralState) {
        Log.i(tag, state.name)
        this.state = state
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(state.ordinal)
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}