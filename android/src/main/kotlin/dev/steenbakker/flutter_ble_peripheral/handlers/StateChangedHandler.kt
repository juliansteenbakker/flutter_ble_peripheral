package dev.steenbakker.flutter_ble_peripheral.handlers

import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.callbacks.PermissionCallback
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel


class StateChangedHandler(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) : EventChannel.StreamHandler {
    private val TAG: String = "StateChangedHandler"

    private var eventSink: EventChannel.EventSink? = null
    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_state_changed"
    )

    private val context: Context = flutterPluginBinding.applicationContext
    private val mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    val bluetoothSupported : Boolean = context.packageManager!!.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
    val bluetoothAuthorized : Boolean
        get() {
            return PermissionCallback.hasPermissions(context)
        }
    val bluetoothPowered : Boolean
        get() {
            return mBluetoothManager?.adapter?.isEnabled == true
        }
    var advertising : Boolean = false
        set(value) {
            field = value
            if (value)
                connected = false
            publishPeripheralState()
        }
    var connected : Boolean = false
        set(value) {
            field = value
            if (value)
                advertising = false
            publishPeripheralState()
        }

    var state : PeripheralState = calculateState()
        private set

    init {
        eventChannel.setStreamHandler(this)
    }

    private fun calculateState(): PeripheralState {
        return if (!bluetoothSupported)
            PeripheralState.unsupported
        else if (!bluetoothAuthorized)
            PeripheralState.unauthorized
        else if (!bluetoothPowered)
            PeripheralState.poweredOff
        else if (connected)
            PeripheralState.connected
        else if (advertising)
            PeripheralState.advertising
        else
            PeripheralState.idle
    }

    fun publishPeripheralState() {
        val state = calculateState()
        if (this.state != state) {
            this.state = state
            Log.i(TAG, state.name)
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(state.ordinal)
            }
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink) {
        this.eventSink = eventSink
        val state = calculateState()
        this.state = state
        Handler(Looper.getMainLooper()).post {
            eventSink.success(state.ordinal)
        }
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}