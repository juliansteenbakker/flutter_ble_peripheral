/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';

import 'package:flutter/services.dart';

import 'advertise_data.dart';

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

  /// Event Channel used to communicate events with
  final EventChannel _eventChannel =
      const EventChannel('dev.steenbakker.flutter_ble_peripheral/ble_event');

  /// Start advertising. Takes [AdvertiseData] as an input.
  Future<void> start(AdvertiseData data) async {
    if (data.uuid == null) {
      throw IllegalArgumentException(
          'Illegal arguments! UUID must not be null or empty');
    }

    Map params = <String, dynamic>{
      'uuid': data.uuid,
      'manufacturerId': data.manufacturerId,
      'manufacturerData': data.manufacturerData,
      'serviceDataUuid': data.serviceDataUuid,
      'serviceData': data.serviceData,
      'includeDeviceName': data.includeDeviceName,
      'deviceName': data.deviceName,
      'transmissionPowerIncluded': data.transmissionPowerIncluded,
      'advertiseMode': data.advertiseMode.index,
      'connectable': data.connectable,
      'timeout': data.timeout,
      'txPowerLevel': data.txPowerLevel.index
    };

    await _methodChannel.invokeMethod('start', params);
  }

  /// Stop advertising
  Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
  }

  /// Returns `true` if advertising or false if not advertising
  Future<bool> isAdvertising() async {
    return await _methodChannel.invokeMethod('isAdvertising');
  }

  /// Returns Stream of booleans indicating if advertising.
  ///
  /// After listening to this Stream, you'll be notified about changes in advertising state.
  /// Returns `true` if advertising. See also: [isAdvertising]
  Stream<bool> getAdvertisingStateChange() {
    return _eventChannel.receiveBroadcastStream().cast<bool>();
  }
}

/// Special exception for illegal arguments
class IllegalArgumentException implements Exception {
  /// Description of exception
  final String message;

  IllegalArgumentException(this.message);

  @override
  String toString() {
    return 'IllegalArgumentException: $message';
  }
}
