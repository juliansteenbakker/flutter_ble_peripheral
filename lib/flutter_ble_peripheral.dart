/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class FlutterBlePeripheral {
  factory FlutterBlePeripheral() {
    if (_instance == null) {
      final MethodChannel methodChannel =
      const MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');

      final EventChannel eventChannel =
      const EventChannel('dev.steenbakker.flutter_ble_peripheral/ble_event');
      _instance = FlutterBlePeripheral.private(methodChannel, eventChannel);
    }
    return _instance;
  }

  @visibleForTesting
  FlutterBlePeripheral.private(this._methodChannel, this._eventChannel);

  static FlutterBlePeripheral _instance;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  /// Start advertising uuid
  Future<void> start(String uuid) async {
    if (uuid == null || uuid.isEmpty) {
      throw new IllegalArgumentException(
          "Illegal arguments! UUID must not be null or empty");
    }

    /// TODO: Add more parameters
    Map params = <String, dynamic>{
      "uuid": uuid,
//      "transmissionPower": _transmissionPower,
//      "identifier": _identifier,
//      "manufacturerId": _manufacturerId,
    };

    await _methodChannel.invokeMethod('start', params);
  }

  /// Stops beacon advertising
  Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
  }

  /// Returns `true` if beacon is advertising
  Future<bool> isAdvertising() async {
    return await _methodChannel.invokeMethod('isAdvertising');
  }

  /// Returns Stream of booleans indicating if beacon is advertising.
  ///
  /// After listening to this Stream, you'll be notified about changes in beacon advertising state.
  /// Returns `true` if beacon is advertising. See also: [isAdvertising()]
  Stream<bool> getAdvertisingStateChange() {
    return _eventChannel.receiveBroadcastStream().cast<bool>();
  }
}

class IllegalArgumentException implements Exception {
  final message;

  IllegalArgumentException(this.message);

  String toString() {
    return "IllegalArgumentException: $message";
  }
}
