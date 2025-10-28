////
////  StateChangedHandler.swift
////  flutter_ble_peripheral
////
////  Created by Julian Steenbakker on 25/03/2022.
////
//
//import Foundation
//
//public class DataReceivedHandler: NSObject, FlutterStreamHandler {
//
//    private var eventSink: FlutterEventSink?
//
//    fileprivate func register(with registrar: FlutterPluginRegistrar, peripheral: FlutterBlePeripheralManager) {
//
//        let eventChannel = FlutterEventChannel(name: "dev.steenbakker.flutter_ble_peripheral/ble_data_received",
//                                               binaryMessenger: registrar.messenger())
//        eventChannel.setStreamHandler(self)
//
//        peripheral.onDataReceived = { data in
//            if let eventSink = self.eventSink {
//                eventSink(FlutterStandardTypedData(bytes: data))
//            }
//        }
//    }
//
//    public func onListen(withArguments arguments: Any?,
//                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
//        self.eventSink = eventSink
//        return nil
//    }
//
//    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
//        eventSink = nil
//        return nil
//    }
//}
