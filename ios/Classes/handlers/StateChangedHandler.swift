//
//  StateChangedHandler.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 25/03/2022.
//

import Foundation
import CoreBluetooth

public class StateChangedHandler: NSObject, FlutterStreamHandler {
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    
    var baseState: CBManagerState = .unknown
    var advertising: Bool = false {
        willSet { if newValue { connected = false } }
    }
    var connected: Bool = false {
        willSet { if newValue { advertising = false } }
    }
    
    private(set) var state: PeripheralState = .unknown
    
    private func calculateState() -> PeripheralState {
        switch baseState {
        case .poweredOff:
            return .poweredOff
        case .unsupported:
            return .unsupported
        case .unauthorized:
            return .unauthorized
        case .unknown:
            return .unknown
        default:
            if connected {
                return .connected
            } else if advertising {
                return .advertising
            } else {
                return .idle
            }
        }
    }
    
    init(registrar: FlutterPluginRegistrar) {
        eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state_changed",
                                               binaryMessenger: registrar.messenger())
        super.init()
        state = calculateState()
        eventChannel.setStreamHandler(self)
    }
    
    /*
     // We can check if advertising is supported by checking if the ios device supports iBeacons since that uses BLE.
     private func isSupported(_ result: @escaping FlutterResult) {
         if (CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self)){
             result(true)
         } else {
             result(false)
         }
     }
     */
    
    func publishPeripheralState() {
        let state = calculateState()
        if self.state != state {
            self.state = state
            if let eventSink = self.eventSink {
                print("publishPeripheralState: ", state)
                eventSink(state.rawValue)
            }
        }
    }
    
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        print("onListen: ", state)
        eventSink(state.rawValue)
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
