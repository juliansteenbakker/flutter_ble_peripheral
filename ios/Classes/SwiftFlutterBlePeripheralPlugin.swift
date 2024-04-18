/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Flutter
import UIKit
import CoreBluetooth

public class SwiftFlutterBlePeripheralPlugin: NSObject, FlutterPlugin {
    
    private let flutterBlePeripheralManager: FlutterBlePeripheralManager
    private let stateHandler: StateChangedHandler
    private let mtuHandler: MtuChangedHandler
    private let dataHandler: DataReceivedHandler
    
    init(registrar: FlutterPluginRegistrar) {
        stateHandler = StateChangedHandler(registrar: registrar)
        mtuHandler = MtuChangedHandler(registrar: registrar)
        dataHandler = DataReceivedHandler(registrar: registrar)
        
        flutterBlePeripheralManager = FlutterBlePeripheralManager(stateHandler: stateHandler, mtuHandler: mtuHandler, dataHandler: dataHandler)
        super.init()
        
        // Method channel
        let methodChannel = FlutterMethodChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(self, channel: methodChannel)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let _ = SwiftFlutterBlePeripheralPlugin(registrar: registrar)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "start":
            startPeripheral(call, result)
        case "stop":
            flutterBlePeripheralManager.stop(result: result)
        case "enableBluetooth":
            result(false)
        case "requestPermission":
            result(flutterBlePeripheralManager.hasPermission())
        case "hasPermission":
            result(flutterBlePeripheralManager.hasPermission())
        case "openAppSettings":
            openAppSettings()
            result(nil)
        case "openBluetoothSettings":
            result(FlutterError(code: "UnsupportedOperation", message: "iOS doesn't allow redirecting to Bluetooth settings", details: nil))
        case "addService":
            addService(call, result)
        case "removeService":
            removeService(call, result)
        case "read":
            read(call, result)
        case "write":
            write(call, result)
        case "disconnect":
            //Disconnect is kinda meaningless in iOS
            //flutterBlePeripheralManager.disconnect()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    private func startPeripheral(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if stateHandler.state != .idle {
            result(FlutterError(code: "InvalidState", message: "Invalid state \(stateHandler.state)", details: stateHandler.state.rawValue))
            return
        }
        
        let map = call.arguments as! Dictionary<String, Any>
        let advertiseData = PeripheralData(properties: map)
        flutterBlePeripheralManager.start(advertiseData: advertiseData, result: result)
    }
    
    private func addService(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let map = call.arguments as! Dictionary<String, Any>
        let service = ServiceDescription(properties: map)
        flutterBlePeripheralManager.addService(description: service, result: result)
    }
    
    private func removeService(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let uuid = call.arguments as! String
        result(flutterBlePeripheralManager.removeService(uuid: CBUUID(string: uuid)))
    }
    
    private func read(_ call: FlutterMethodCall, _ result: FlutterResult) {
        result(flutterBlePeripheralManager.read(characteristic: CBUUID(string: call.arguments as! String)))
    }
    
    private func write(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let map = call.arguments as! Dictionary<String,Any>
        let uuid = CBUUID(string: map["characteristic"] as! String)
        let data = (map["data"] as! FlutterStandardTypedData).data
        flutterBlePeripheralManager.write(characteristic: uuid, data: data, result: result)
    }
}
