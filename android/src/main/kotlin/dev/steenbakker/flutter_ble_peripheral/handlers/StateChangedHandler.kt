package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class StateChangedHandler(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) : EventChannel.StreamHandler {
    private val TAG: String = "StateChangedHandler"

    private var eventSink: EventChannel.EventSink? = null

    private var state = PeripheralState.idle

    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_state_changed"
    )

    init {
        eventChannel.setStreamHandler(this)
        //publishPeripheralState(PeripheralState.poweredOff)
    }

    fun getState() : PeripheralState {
        return state
    }

    fun publishPeripheralState(state: PeripheralState) {
        if (this.state != state) {
            Log.i(TAG, state.name)
            this.state = state
            Handler(Looper.getMainLooper()).post {
                eventSink!!.success(state.ordinal)
            }
        } else {
            Log.i(TAG, "O estado nao mudou, publish repetido") //TODO: tirar. tirar if tmb??
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
        //publishPeripheralState(state)
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}