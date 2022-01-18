/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Flutter
import UIKit
import CoreLocation

public class SwiftFlutterBlePeripheralPlugin: NSObject, FlutterPlugin {
    
    private let flutterBlePeripheralManager = FlutterBlePeripheralManager()
    
    private let stateChangedHandler = StateChangedHandler()
    private let mtuChangedHandler = MtuChangedHandler()
    private let dataReceivedHandler = DataReceivedHandler()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        
        let instance = SwiftFlutterBlePeripheralPlugin()
        
        // Method channel
        let methodChannel = FlutterMethodChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // Event channels
        instance.stateChangedHandler.register(with: registrar, peripheral: instance.flutterBlePeripheralManager)
        instance.mtuChangedHandler.register(with: registrar, peripheral: instance.flutterBlePeripheralManager)
        instance.dataReceivedHandler.register(with: registrar, peripheral: instance.flutterBlePeripheralManager)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "start":
            startPeripheral(call, result)
        case "stop":
            stopPeripheral(call, result)
        case "isAdvertising":
            result(flutterBlePeripheralManager.isAdvertising())
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
    
    private func startPeripheral(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let map = call.arguments as? Dictionary<String, Any>
        let advertiseData = PeripheralData(
            uuid: map?["uuid"] as? String ,
            localName: map?["localName"] as? String
        )
        flutterBlePeripheralManager.start(advertiseData: advertiseData)
        result(nil)
    }
    
    private func stopPeripheral(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        flutterBlePeripheralManager.stop()
        result(nil)
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
        result(flutterBlePeripheralManager.isConnected())
    }
    
    private func sendData(_ call: FlutterMethodCall,
                          _ result: @escaping FlutterResult) {
        
        if let flutterData = call.arguments as? FlutterStandardTypedData {
          flutterBlePeripheralManager.send(data: flutterData.data)
        }
        result(nil)
    }
}

public class StateChangedHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    fileprivate func register(with registrar: FlutterPluginRegistrar, peripheral: FlutterBlePeripheralManager) {
        
        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state_changed",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(self)
        
        peripheral.onStateChanged = { peripheralState in
          if let eventSink = self.eventSink {
              eventSink(peripheralState.rawValue)
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

public class MtuChangedHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    fileprivate func register(with registrar: FlutterPluginRegistrar, peripheral: FlutterBlePeripheralManager) {
        
        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(self)
        
        peripheral.onMtuChanged = { mtuSize in
            if let eventSink = self.eventSink {
                eventSink(mtuSize)
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
    
    fileprivate func register(with registrar: FlutterPluginRegistrar, peripheral: FlutterBlePeripheralManager) {
        
        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_data_received",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(self)
        
        peripheral.onDataReceived = { data in
            if let eventSink = self.eventSink {
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
