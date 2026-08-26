package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * Broadcasts whether any central is subscribed to the TX characteristic.
 *
 * A central has to write the CCCD before the peripheral may notify it, so this
 * is the state in which `sendData` can actually deliver. It is not the same as
 * being connected: a central may connect and never subscribe.
 *
 * The value is sent to Flutter as a boolean.
 *
 * Event channel name: `dev.steenbakker.flutter_ble_peripheral/ble_subscription_changed`
 */
class SubscriptionChangedHandler(
    flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : EventChannel.StreamHandler {

    /** The event sink used to send subscription updates to Flutter. */
    private var eventSink: EventChannel.EventSink? = null

    /** The last value published, so that only changes are sent. */
    private var subscribed: Boolean? = null

    /** Event channel used to communicate with Flutter. */
    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_subscription_changed"
    )

    init {
        eventChannel.setStreamHandler(this)
    }

    /**
     * Publishes whether a central is subscribed, if that changed since the last
     * call.
     *
     * @param subscribed Whether at least one central is subscribed to TX.
     */
    fun publish(subscribed: Boolean) {
        if (this.subscribed == subscribed) return
        this.subscribed = subscribed
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(subscribed)
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}
