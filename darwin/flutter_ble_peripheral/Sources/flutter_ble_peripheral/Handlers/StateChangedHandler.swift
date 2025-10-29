//
//  StateChangedHandler.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

public class StateChangedHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    var state: FlutterBlePeripheralState = FlutterBlePeripheralState.idle
    
    private let eventChannel: FlutterEventChannel
    
    init(registrar: FlutterPluginRegistrar) {
#if os(iOS)
        let messenger = registrar.messenger()
#else
        let messenger = registrar.messenger
#endif
        eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state_changed",
                                               binaryMessenger: messenger)
        super.init()
        eventChannel.setStreamHandler(self)
    }
    
    func publishPeripheralState(state: FlutterBlePeripheralState) {
        self.state = state
        if let eventSink = self.eventSink {
            eventSink(state.rawValue)
        }
    }
    
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        if let eventSink = self.eventSink {
            eventSink(state.rawValue)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil 
        return nil
    }
}
