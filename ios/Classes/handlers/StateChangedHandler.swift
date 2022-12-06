//
//  StateChangedHandler.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import Foundation

public class StateChangedHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    var state: PeripheralState = PeripheralState.idle
    
    private let eventChannel: FlutterEventChannel
    
    init(registrar: FlutterPluginRegistrar) {
        eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state_changed",
                                               binaryMessenger: registrar.messenger())
        super.init()
        eventChannel.setStreamHandler(self)
    }
    
    func publishPeripheralState(state: PeripheralState) {
        self.state = state
        if let eventSink = self.eventSink {
            eventSink(state.rawValue)
        }
    }
    
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        publishPeripheralState(state: state)
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
