/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';

import 'package:flutter/services.dart';

import 'advertise_data.dart';

class FlutterBlePeripheral {
  static final FlutterBlePeripheral _instance =
      FlutterBlePeripheral._internal();

  final MethodChannel _methodChannel =
      const MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');
  final EventChannel _eventChannel =
      const EventChannel('dev.steenbakker.flutter_ble_peripheral/ble_event');

  factory FlutterBlePeripheral() {
    return _instance;
  }

  FlutterBlePeripheral._internal();

  /// Start advertising. Takes [AdvertiseData] as an input.
  Future<void> start(AdvertiseData data) async {
    if (data.uuid == null) {
      throw IllegalArgumentException(
          'Illegal arguments! UUID must not be null or empty');
    }

    Map params = <String, dynamic>{
      'uuid': data.uuid,
      'transmissionPowerIncluded': data.transmissionPowerIncluded,
      'manufacturerId': data.manufacturerId,
      'manufacturerData': data.manufacturerData,
      'serviceDataUuid': data.serviceDataUuid,
      'serviceData': data.serviceData,
      'includeDeviceName': data.includeDeviceName
    };

    await _methodChannel.invokeMethod('start', params);
  }

  /// Stop advertising.
  Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
  }

  // TODO: Fix isAdvertising
  /// Returns `true` if advertising
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

class IllegalArgumentException implements Exception {
  final String message;

  IllegalArgumentException(this.message);

  @override
  String toString() {
    return 'IllegalArgumentException: $message';
  }
}
