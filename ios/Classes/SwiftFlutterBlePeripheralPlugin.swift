/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Flutter
import UIKit
import CoreLocation

public class SwiftFlutterBlePeripheralPlugin: NSObject, FlutterPlugin {
    
    private let peripheral = Peripheral()
    
    private let stateChangedHandler = StateChangedHandler()
    private let dataReceivedHandler = DataReceivedHandler()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        
        let instance = SwiftFlutterBlePeripheralPlugin()
        
        // Method channel
        let methodChannel = FlutterMethodChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // Event channels
        instance.stateChangedHandler.register(with: registrar, peripheral: instance.peripheral)
        instance.dataReceivedHandler.register(with: registrar, peripheral: instance.peripheral)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch (call.method) {
        case "start":
            startAdvertising(call, result)
        case "stop":
            stopAdvertising(call, result)
        case "isAdvertising":
            isAdvertising(call, result)
        case "isSupported":
            isSupported(result)
        case "isConnected":
            isConnected(call, result)
        case "sendData":
            sendData(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startAdvertising(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let map = call.arguments as? Dictionary<String, Any>
        let advertiseData = AdvertiseData(
            uuid: map?["uuid"] as? String ,
            localName: map?["localName"] as? String
        )
        peripheral.start(advertiseData: advertiseData)
        result(nil)
    }
    
    private func stopAdvertising(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        peripheral.stop()
        result(nil)
    }
    
    private func isAdvertising(_ call: FlutterMethodCall,
                               _ result: @escaping FlutterResult) {
        result(peripheral.isAdvertising())
    }
    
    // We can check if advertising is supported by checking if the ios device supports iBeacons since that uses BLE.
    private func isSupported(_ result: @escaping FlutterResult) {
        if (CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self)){
            result(true)
        } else {
            result(false)
        }
    }
    
    private func isConnected(_ call: FlutterMethodCall,
                             _ result: @escaping FlutterResult) {
        result(peripheral.isConnected())
    }
    
    private func sendData(_ call: FlutterMethodCall,
                          _ result: @escaping FlutterResult) {
        
        if let flutterData = call.arguments as? FlutterStandardTypedData {
          peripheral.send(data: flutterData.data)
        }
        result(nil)
    }
}

public class StateChangedHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    fileprivate func register(with registrar: FlutterPluginRegistrar, peripheral: Peripheral) {
        
        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state_changed",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(self)
        
        peripheral.onAdvertisingStateChanged = { isAdvertising in
            if (self.eventSink != nil) {
              print("[StateChangedHandler] state: \(isAdvertising)")
              self.eventSink!(isAdvertising)
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

public class DataReceivedHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    fileprivate func register(with registrar: FlutterPluginRegistrar, peripheral: Peripheral) {
        
        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_data_received",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(self)
        
        peripheral.onDataReceived = { data in
            if let eventSink = self.eventSink {
                print("[DataReceivedHandler] data: \(data)")
                eventSink(FlutterStandardTypedData(bytes: data))
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
