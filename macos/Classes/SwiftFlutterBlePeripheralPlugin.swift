/*
* Copyright (c) 2020. Julian Steenbakker.
* All rights reserved. Use of this source code is governed by a
* BSD-style license that can be found in the LICENSE file.
*/

import FlutterMacOS

public class SwiftFlutterBlePeripheralPlugin: NSObject, FlutterPlugin,
    FlutterStreamHandler {

    private var peripheral = Peripheral()
    private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SwiftFlutterBlePeripheralPlugin()

    let channel = FlutterMethodChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_state", binaryMessenger: registrar.messenger)

    let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_event",
                                           binaryMessenger: registrar.messenger)
    eventChannel.setStreamHandler(instance)
    instance.registerBeaconListener()

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    func registerBeaconListener() {
        peripheral.onAdvertisingStateChanged = {isAdvertising in
            if (self.eventSink != nil) {
                self.eventSink!(isAdvertising)
            }
        }
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch (call.method) {
      case "start":
          startBeacon(call, result)
      case "stop":
          stopBeacon(call, result)
      case "isAdvertising":
          isAdvertising(call, result)
      case "isTransmissionSupported":
          isTransmissionSupported(call, result)
      default:
          result(FlutterMethodNotImplemented)
      }
  }

    private func startBeacon(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let map = call.arguments as? Dictionary<String, Any>
        let advertiseData = AdvertiseData(
            uuid: map?["uuid"] as! String,
            transmissionPower: map?["transmissionPower"] as? NSNumber
//            identifier: map?["identifier"] as! String
        )
        peripheral.start(advertiseData: advertiseData)
        result(nil)
    }

    private func stopBeacon(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        peripheral.stop()
        result(nil)
    }

    private func isAdvertising(_ call: FlutterMethodCall,
                               _ result: @escaping FlutterResult) {
        result(peripheral.isAdvertising())
    }

    private func isTransmissionSupported(_ call: FlutterMethodCall,
                               _ result: @escaping FlutterResult) {
        result(0)
    }
}
