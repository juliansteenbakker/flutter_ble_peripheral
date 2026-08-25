package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * Handles broadcasting BLE MTU (Maximum Transmission Unit) changes
 * from the Android side to the Flutter side via an [EventChannel].
 *
 * This class acts as a bridge that sends updates whenever the MTU size changes,
 * typically after a BLE connection is established and negotiated with a client.
 *
 * The new MTU value is sent to Flutter as an integer.
 *
 * Event channel name: `dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed`
 */
class MtuChangedHandler(
    flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : EventChannel.StreamHandler {

    /** The event sink used to send MTU change updates to Flutter. */
    private var eventSink: EventChannel.EventSink? = null

    /** Event channel used to communicate with Flutter. */
    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed"
    )

    init {
        // Set up the event channel used to communicate MTU updates with Flutter.
        eventChannel.setStreamHandler(this)
    }

    /**
     * Publishes a new MTU value to the Flutter side.
     *
     * This method ensures that the update is dispatched on the main thread
     * (required for communication through Flutter’s platform channels).
     *
     * @param mtu The updated Maximum Transmission Unit value.
     */
    fun publish(mtu: Int) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(mtu)
        }
    }

    /**
     * Called when the Flutter side starts listening for MTU change events.
     *
     * Stores the [eventSink] reference so that MTU updates can be sent.
     *
     * @param event Optional event arguments from Flutter (usually `null`).
     * @param eventSink The [EventChannel.EventSink] used to send MTU updates.
     */
    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    /**
     * Called when the Flutter side cancels its MTU change subscription.
     *
     * Clears the [eventSink] reference to stop sending further updates.
     *
     * @param event Optional event arguments from Flutter (usually `null`).
     */
    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}
