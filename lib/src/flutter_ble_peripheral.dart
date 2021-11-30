/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/src/models/peripheral_state.dart';

import '../flutter_ble_peripheral.dart';
import 'models/advertise_data.dart';

class FlutterBlePeripheral {
  /// Singleton instance
  static final FlutterBlePeripheral _instance =
      FlutterBlePeripheral._internal();

  /// Singleton factory
  factory FlutterBlePeripheral() {
    return _instance;
  }

  /// Singleton constructor
  FlutterBlePeripheral._internal();

  /// Method Channel used to communicate state with
  final MethodChannel _methodChannel =
      const MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');

  /// Event Channel for MTU state
  final EventChannel _mtuChangedEventChannel = const EventChannel(
      'dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed');

  /// Event Channel used to changed state
  final EventChannel _stateChangedEventChannel = const EventChannel(
      'dev.steenbakker.flutter_ble_peripheral/ble_state_changed');

  // Event Channel used to received data
  final EventChannel _dataReceivedEventChannel = const EventChannel(
      'dev.steenbakker.flutter_ble_peripheral/ble_data_received');

  /// Start advertising. Takes [AdvertiseData] as an input.
  Future<void> start(AdvertiseData data) async {
    debugPrint('Start advertising');
    Map params = <String, dynamic>{
      'uuid': data.uuid,
      'manufacturerId': data.manufacturerId,
      'manufacturerData': data.manufacturerData,
      'serviceDataUuid': data.serviceDataUuid,
      'serviceData': data.serviceData,
      'includeDeviceName': data.includeDeviceName,
      'localName': data.localName,
      'transmissionPowerIncluded': data.includePowerLevel,
      'advertiseMode': data.advertiseMode.index,
      'connectable': data.connectable,
      'timeout': data.timeout,
      'txPowerLevel': data.txPowerLevel.index
    };

    await _methodChannel.invokeMethod('start', params);
  }

  /// Stop advertising
  Future<void> stop() async {
    debugPrint('Stop advertising');
    await _methodChannel.invokeMethod('stop');
  }

  /// Returns `true` if advertising or false if not advertising
  Future<bool> isAdvertising() async {
    return await _methodChannel.invokeMethod('isAdvertising');
  }

  /// Returns `true` if advertising over BLE is supported
  Future<bool> isSupported() async {
    return await _methodChannel.invokeMethod('isSupported');
  }

  /// Returns `true` if device is connected
  Future<bool> isConnected() async {
    return await _methodChannel.invokeMethod('isConnected');
  }

  /// Start advertising. Takes [AdvertiseData] as an input.
  Future<void> sendData(Uint8List data) async {
    debugPrint('Send data: $data');
    await _methodChannel.invokeMethod('sendData', data);
  }

  /// Returns Stream of MTU updates.
  Stream<int> getMtuChanged() {
    return _mtuChangedEventChannel
        .receiveBroadcastStream()
        .cast<int>()
        .distinct().map((event) {
          debugPrint('mtu: $event');
      return event;
    } );
  }

  /// Returns Stream of state.
  ///
  /// After listening to this Stream, you'll be notified about changes in peripheral state.
  Stream<PeripheralState> getStateChanged() {
    return _stateChangedEventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          debugPrint('state: ');
          return PeripheralState.values[event as int];
        });
  }

  /// Returns Stream of data.
  ///
  ///
  Stream<Uint8List> getDataReceived() {
    return _dataReceivedEventChannel.receiveBroadcastStream().cast<Uint8List>();
  }
}