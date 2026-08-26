package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * Handles broadcasting changes in the BLE (Bluetooth Low Energy) peripheral state
 * from the Android side to the Flutter side via an [EventChannel].
 *
 * This class acts as a bridge for sending updates about the peripheral’s state,
 * such as when it becomes active, idle, advertising, or encounters an error.
 *
 * The state is sent to Flutter as an integer corresponding to the [ordinal]
 * of the [PeripheralState] enum.
 *
 * Event channel name: `dev.steenbakker.flutter_ble_peripheral/ble_state_changed`
 */
class PeripheralStateChangedHandler(
    flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : EventChannel.StreamHandler {

    /** Tag used for logging BLE peripheral state changes. */
    private val tag: String = "BLE Peripheral state "

    /** The event sink used to send events to the Flutter side. */
    private var eventSink: EventChannel.EventSink? = null

    /** The current BLE peripheral state. */
    var state = PeripheralState.idle

    /** Event channel used to communicate with Flutter. */
    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_state_changed"
    )

    init {
        eventChannel.setStreamHandler(this)
    }

    /**
     * Publishes the given [state] to the Flutter side.
     *
     * This method logs the state change and posts the update
     * to the main thread to ensure thread safety when sending data
     * through the Flutter [EventChannel].
     *
     * @param state The new [PeripheralState] to publish.
     */
    fun publish(state: PeripheralState) {
        Log.i(tag, state.name)
        this.state = state
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(state.ordinal)
        }
    }

    /**
     * Called when the Flutter side starts listening to the event stream.
     *
     * This method stores the [eventSink] reference and immediately
     * publishes the current state to the listener.
     *
     * @param event Unused event argument from Flutter (may be `null`).
     * @param eventSink The [EventChannel.EventSink] used to send events to Flutter.
     */
    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
        publish(state)
    }

    /**
     * Called when the Flutter side cancels the event subscription.
     *
     * This method clears the [eventSink] reference to stop sending updates.
     *
     * @param event Unused event argument from Flutter (may be `null`).
     */
    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}
