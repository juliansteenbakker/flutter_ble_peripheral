/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Flutter
import UIKit
import CoreLocation
import Foundation
import CoreBluetooth
import CoreLocation

public class SwiftFlutterBlePeripheralPlugin: NSObject, FlutterPlugin {
    
    private let flutterBlePeripheralManager: FlutterBlePeripheralManager
    
    private let stateChangedHandler: StateChangedHandler
//    private let mtuChangedHandler = MtuChangedHandler()
//    private let dataReceivedHandler = DataReceivedHandler()
    init(stateChangedHandler: StateChangedHandler) {
        self.stateChangedHandler = stateChangedHandler
        flutterBlePeripheralManager = FlutterBlePeripheralManager(stateChangedHandler: stateChangedHandler)
        super.init()
    }
    public static var result: FlutterResult? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterBlePeripheralPlugin(stateChangedHandler: StateChangedHandler(registrar: registrar))
        
        // Method channel
        let methodChannel = FlutterMethodChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Event channels
//        instance.mtuChangedHandler.register(with: registrar, peripheral: instance.flutterBlePeripheralManager)
//        instance.dataReceivedHandler.register(with: registrar, peripheral: instance.flutterBlePeripheralManager)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "start":
            startPeripheral(call, result)
        case "stop":
            stopPeripheral(result)
        case "isAdvertising":
            result(stateChangedHandler.state == PeripheralState.advertising)
        case "isSupported":
            isSupported(result)
        case "isConnected":
            result(stateChangedHandler.state == PeripheralState.connected)
        case "requestPermission", "enableBluetooth":
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, completionHandler: nil)
            }
//        case "sendData":
//            sendData(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startPeripheral(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if (stateChangedHandler.state == .unauthorized) {
            result(FlutterError(code: "12", message: "App is not authorized to use bluetooth", details: nil))
            return
        } else if (stateChangedHandler.state == .poweredOff) {
            result(FlutterError(code: "13", message: "Bluetooth is turned off", details: nil))
            return
        }
        SwiftFlutterBlePeripheralPlugin.result = result
        let map = call.arguments as? Dictionary<String, Any>
        let advertiseData = PeripheralData(
            uuid: map?["uuid"] as? String ,
            localName: map?["localName"] as? String
        )
        flutterBlePeripheralManager.start(advertiseData: advertiseData)
    }
    
    private func stopPeripheral(_ result: @escaping FlutterResult) {
        flutterBlePeripheralManager.peripheralManager.stopAdvertising()
        stateChangedHandler.publishPeripheralState(state: PeripheralState.idle)
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
    
//    private func sendData(_ call: FlutterMethodCall,
//                          _ result: @escaping FlutterResult) {
//
//        if let flutterData = call.arguments as? FlutterStandardTypedData {
//          flutterBlePeripheralManager.send(data: flutterData.data)
//        }
//        result(nil)
//    }
}
