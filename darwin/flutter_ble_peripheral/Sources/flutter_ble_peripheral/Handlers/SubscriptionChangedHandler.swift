/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import CoreBluetooth

#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

/**
 Broadcasts whether any central is subscribed to the TX characteristic.

 A central has to subscribe before the peripheral may notify it, so this is the
 state in which `sendData` can actually deliver. It is not the same as being
 connected: a central may connect and never subscribe.

 Event channel name: `dev.steenbakker.flutter_ble_peripheral/ble_subscription_changed`
 */
public class SubscriptionChangedHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var registrar: FlutterPluginRegistrar

    /// The last value published per characteristic, so only changes are sent.
    private var subscribed: [CBUUID: Bool] = [:]

    /// The last aggregate published, replayed to a new listener.
    private var anySubscribed: Bool?

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
        setupEventChannel()
    }

    private func setupEventChannel() {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif

        let eventChannel = FlutterEventChannel(
            name: "dev.steenbakker.flutter_ble_peripheral/ble_subscription_changed",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)
    }

    func publish(characteristicUuid: CBUUID, subscribed: Bool, anySubscribed: Bool) {
        guard self.subscribed[characteristicUuid] != subscribed else { return }
        self.subscribed[characteristicUuid] = subscribed
        self.anySubscribed = anySubscribed
        let event: [String: Any] = [
            "characteristicUuid": FlutterBlePeripheralManager.fullUuid(characteristicUuid),
            "subscribed": subscribed,
            "anySubscribed": anySubscribed,
        ]
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }

    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        // A new listener is given the current state, since the subscription it
        // describes may predate it: after a background relaunch the central is
        // already subscribed before Dart attaches.
        for (uuid, subscribed) in self.subscribed {
            eventSink([
                "characteristicUuid": FlutterBlePeripheralManager.fullUuid(uuid),
                "subscribed": subscribed,
                "anySubscribed": anySubscribed ?? subscribed,
            ] as [String: Any])
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
