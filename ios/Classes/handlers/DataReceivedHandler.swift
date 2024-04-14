//
//  DataChangedHandler.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import Foundation
import CoreBluetooth

public class DataReceivedHandler: NSObject, FlutterStreamHandler {
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    
    init(registrar: FlutterPluginRegistrar) {
        eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_data_received",
                                               binaryMessenger: registrar.messenger())
        super.init()
        eventChannel.setStreamHandler(self)
    }
    
    func publishData(characteristic: CBUUID, value: Data) {
        eventSink?([
            "characteristic": characteristic.uuidString,
            "value": value
        ])
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
