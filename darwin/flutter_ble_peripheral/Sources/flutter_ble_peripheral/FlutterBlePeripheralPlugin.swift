/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif
import CoreLocation

public class FlutterBlePeripheralPlugin: NSObject, FlutterPlugin {
    
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
        let instance = FlutterBlePeripheralPlugin(stateChangedHandler: StateChangedHandler(registrar: registrar))
        
#if os(iOS)
        let messenger = registrar.messenger()
#else
        let messenger = registrar.messenger
#endif
        
        // Method channel
        let methodChannel = FlutterMethodChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state", binaryMessenger: messenger)
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
            result(stateChangedHandler.state == FlutterBlePeripheralState.advertising)
        case "isSupported":
            isSupported(result)
        case "isConnected":
            result(stateChangedHandler.state == FlutterBlePeripheralState.connected)
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
        let advertiseData = FlutterBlePeripheralData(
            uuid: map?["serviceUuid"] as? String ,
            localName: map?["localName"] as? String,
            uuids: map?["serviceUuids"] as? [String] ,
        )
        flutterBlePeripheralManager.start(advertiseData: advertiseData)
        result(nil)
    }
    
    private func stopPeripheral(_ result: @escaping FlutterResult) {
        flutterBlePeripheralManager.peripheralManager.stopAdvertising()
        stateChangedHandler.publishPeripheralState(state: FlutterBlePeripheralState.idle)
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
#if os(iOS)
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
#else
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
#endif
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
