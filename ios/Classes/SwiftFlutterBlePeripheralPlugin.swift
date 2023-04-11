/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import Flutter
import UIKit
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
        case "openBluetoothSettings":
            openAppSettings()
            result(nil)
//        case "sendData":
//            sendData(call, result)
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
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
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
