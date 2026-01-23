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
import CoreBluetooth

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
        case "isBluetoothOn":
            result(flutterBlePeripheralManager.peripheralManager.state == .poweredOn)
        case "hasPermission":
            result(getPermissionState())
        case "requestPermission":
            // On iOS/macOS, permissions are requested implicitly when using Bluetooth
            // The CBPeripheralManager initialization triggers the permission request
            result(getPermissionState())
        case "enableBluetooth":
            // Cannot programmatically enable Bluetooth on iOS/macOS
            result(false)
        case "openBluetoothSettings":
            openBluetoothSettings()
            result(nil)
        case "openAppSettings":
            openAppSettings()
            result(nil)
//        case "sendData":
//            sendData(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Returns permission state ordinal matching BluetoothPeripheralState enum
    // 0=granted, 1=denied, 2=permanentlyDenied, 3=restricted, 7=unknown
    // Note: This checks PERMISSION status only, not Bluetooth power state (use isBluetoothOn for that)
    private func getPermissionState() -> Int {
        // First try the authorization API (iOS 13.1+/macOS 10.15+)
        // This gives us permission status regardless of Bluetooth power state
        if #available(iOS 13.1, macOS 10.15, *) {
            switch CBPeripheralManager.authorization {
            case .allowedAlways:
                return 0 // granted
            case .denied:
                return 2 // permanentlyDenied
            case .restricted:
                return 3 // restricted
            case .notDetermined:
                return 1 // denied (needs to request)
            @unknown default:
                break // fall through to state-based check
            }
        }

        // Fallback for older OS: infer permission from peripheral manager state
        let state = flutterBlePeripheralManager.peripheralManager.state
        switch state {
        case .unauthorized:
            return 2 // permanentlyDenied
        case .poweredOn, .poweredOff:
            return 0 // granted (if we get these states, we have permission)
        case .unsupported:
            return 6 // unsupported
        case .unknown, .resetting:
            return 7 // unknown
        @unknown default:
            return 7 // unknown
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
    
    private func isSupported(_ result: @escaping FlutterResult) {
        // Check if the peripheral manager state indicates BLE is unsupported
        result(flutterBlePeripheralManager.peripheralManager.state != .unsupported)
    }
    
    private func openBluetoothSettings() {
#if os(iOS)
        // Cannot open bluetooth settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#else
        // Open System Settings to Bluetooth pane on macOS
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
#endif
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
