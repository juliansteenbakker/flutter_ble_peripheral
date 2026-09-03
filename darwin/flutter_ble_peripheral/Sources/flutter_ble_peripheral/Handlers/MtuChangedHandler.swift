//
//  MtuChangedHandler.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif

public class MtuChangedHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var registrar: FlutterPluginRegistrar

    /// The last mtu published, replayed to a new listener.
    private var mtu: Int?

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

        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed",
                                               binaryMessenger: messenger)
        eventChannel.setStreamHandler(self)
    }

    func publishMtu(mtu: Int) {
        self.mtu = mtu
        DispatchQueue.main.async {
            if let eventSink = self.eventSink {
                eventSink(mtu)
            }
        }
    }

    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        // The mtu is negotiated once, when the central connects, which after a
        // background relaunch is before Dart attaches, so a new listener is given
        // the last value rather than waiting for a connection it already has.
        if let mtu = mtu {
            eventSink(mtu)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
