package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * Handles broadcasting data received over a BLE (Bluetooth Low Energy)
 * peripheral connection from Android to Flutter using an [EventChannel].
 *
 * This class is responsible for relaying raw data (in bytes) received
 * by the BLE peripheral through the [FlutterBlePeripheralManager]
 * to the Flutter layer for processing or display.
 *
 * The event stream sends a `ByteArray` representing the received data.
 *
 * Event channel name: `dev.steenbakker.flutter_ble_peripheral/ble_data_received`
 */
class DataReceivedHandler(
    flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : EventChannel.StreamHandler {

    /** The event sink used to send data received events to Flutter. */
    private var eventSink: EventChannel.EventSink? = null

    /** Event channel used to communicate with Flutter. */
    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_data_received"
    )

    init {
        // Set up the event channel used to communicate BLE data reception events with Flutter.
        eventChannel.setStreamHandler(this)
    }

    /**
     * Publishes received BLE data to the Flutter side.
     *
     * This method posts the data to the main thread (required for Flutter platform channels)
     * and sends it through the event sink if a listener is active.
     *
     * @param data The raw data received over BLE, represented as a [ByteArray].
     */
    fun publish(data: ByteArray) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(data)
        }
    }

    /**
     * Called when the Flutter side starts listening to the BLE data stream.
     *
     * Stores the [eventSink] reference, allowing future data packets
     * to be sent to Flutter.
     *
     * @param event Optional event arguments from Flutter (usually `null`).
     * @param eventSink The [EventChannel.EventSink] used to send data updates.
     */
    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    /**
     * Called when the Flutter side cancels its BLE data subscription.
     *
     * Clears the [eventSink] reference to stop further data transmissions.
     *
     * @param event Optional event arguments from Flutter (usually `null`).
     */
    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}
