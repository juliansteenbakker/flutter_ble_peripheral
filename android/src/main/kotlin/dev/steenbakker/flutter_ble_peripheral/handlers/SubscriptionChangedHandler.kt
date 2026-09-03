package dev.steenbakker.flutter_ble_peripheral.handlers

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import java.util.UUID

/**
 * Broadcasts whether a central is subscribed to a notifying characteristic.
 *
 * A central has to write the CCCD before the peripheral may notify it, so this
 * is the state in which `sendData` can actually deliver. It is not the same as
 * being connected: a central may connect and never subscribe.
 *
 * Each event is a map of the characteristic uuid, whether that one has a
 * subscriber, and whether anything at all has one, so that Dart can offer both
 * the per-characteristic stream and the single boolean.
 *
 * Event channel name: `dev.steenbakker.flutter_ble_peripheral/ble_subscription_changed`
 */
class SubscriptionChangedHandler(
    flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : EventChannel.StreamHandler {

    /** The event sink used to send subscription updates to Flutter. */
    private var eventSink: EventChannel.EventSink? = null

    /** The last value published per characteristic, so only changes are sent. */
    private val subscribed = mutableMapOf<UUID, Boolean>()

    /** Event channel used to communicate with Flutter. */
    private val eventChannel = EventChannel(
        flutterPluginBinding.binaryMessenger,
        "dev.steenbakker.flutter_ble_peripheral/ble_subscription_changed"
    )

    init {
        eventChannel.setStreamHandler(this)
    }

    /**
     * Publishes whether a central is subscribed to [uuid], if that changed since
     * the last call for that characteristic.
     *
     * @param uuid The characteristic whose subscribers changed.
     * @param subscribed Whether at least one central is subscribed to it.
     * @param anySubscribed Whether any characteristic has a subscriber.
     */
    fun publish(uuid: UUID, subscribed: Boolean, anySubscribed: Boolean) {
        if (this.subscribed[uuid] == subscribed) return
        this.subscribed[uuid] = subscribed
        val event = mapOf(
            "characteristicUuid" to uuid.toString(),
            "subscribed" to subscribed,
            "anySubscribed" to anySubscribed,
        )
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(event)
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        this.eventSink = null
    }
}
