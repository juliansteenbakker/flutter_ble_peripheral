//
//  DataReceivedHandler.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import CoreBluetooth

#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif

public class DataReceivedHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var registrar: FlutterPluginRegistrar

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

        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_data_received",
                                               binaryMessenger: messenger)
        eventChannel.setStreamHandler(self)
    }

    func publishData(characteristicUuid: CBUUID, data: Data) {
        let event: [String: Any] = [
            "characteristicUuid": FlutterBlePeripheralManager.fullUuid(characteristicUuid),
            "data": FlutterStandardTypedData(bytes: data),
        ]
        DispatchQueue.main.async {
            if let eventSink = self.eventSink {
                eventSink(event)
            }
        }
    }

    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
