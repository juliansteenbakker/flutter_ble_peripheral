/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/src/models/advertise_data.dart';
import 'package:flutter_ble_peripheral/src/models/advertise_set_parameters.dart';
import 'package:flutter_ble_peripheral/src/models/advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/models/periodic_advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/models/peripheral_state.dart';

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
  static const MethodChannel _methodChannel =
      MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');

  /// Event Channel for MTU state
  final EventChannel _mtuChangedEventChannel = const EventChannel(
    'dev.steenbakker.flutter_ble_peripheral/ble_mtu_changed',
  );

  /// Event Channel used to changed state
  final EventChannel _stateChangedEventChannel = const EventChannel(
    'dev.steenbakker.flutter_ble_peripheral/ble_state_changed',
  );

  Stream<int>? _mtuState;
  Stream<PeripheralState>? _peripheralState;

  //TODO Event Channel used to received data
  // final EventChannel _dataReceivedEventChannel = const EventChannel(
  //     'dev.steenbakker.flutter_ble_peripheral/ble_data_received');

  /// Start advertising. Takes [AdvertiseData] as an input.
  Future<void> start({
    required AdvertiseData advertiseData,
    AdvertiseSettings? advertiseSettings,
    AdvertiseSetParameters? advertiseSetParameters,
    AdvertiseData? advertiseResponseData,
    AdvertiseData? advertisePeriodicData,
    PeriodicAdvertiseSettings? periodicAdvertiseSettings,
  }) async {
    final Map<String, dynamic> parameters = {
      'uuid': advertiseData.serviceUuid,
      'manufacturerId': advertiseData.manufacturerId,
      'manufacturerData': advertiseData.manufacturerData,
      'serviceDataUuid': advertiseData.serviceDataUuid,
      'serviceData': advertiseData.serviceData,
      'includeDeviceName': advertiseData.includeDeviceName,
      'localName': advertiseData.localName,
      'transmissionPowerIncluded': advertiseData.includePowerLevel,
      'serviceSolicitationUuid': advertiseData.serviceSolicitationUuid,
    };

    if (advertiseSettings != null && advertiseSetParameters != null) {
      throw Exception(
        "You can't define both advertiseSettings & setAdvertiseSettings",
      );
    } else if (advertiseSettings != null) {
      parameters.addAll({
        'advertiseMode': advertiseSettings.advertiseMode.index,
        'connectable': advertiseSettings.connectable,
        'timeout': advertiseSettings.timeout,
        'txPowerLevel': advertiseSettings.txPowerLevel.index,
      });
    } else if (advertiseSetParameters != null) {
      parameters.addAll({
        'advertiseSet': true,
        'connectable': advertiseSetParameters.connectable,
        'txPowerLevel': advertiseSetParameters.txPowerLevel,
        'interval': advertiseSetParameters.interval,
        'legacyMode': advertiseSetParameters.legacyMode,
        'primaryPhy': advertiseSetParameters.primaryPhy,
        'scannable': advertiseSetParameters.scannable,
        'secondaryPhy': advertiseSetParameters.secondaryPhy,
        'anonymous': advertiseSetParameters.anonymous,
        'includeTxPowerLevel': advertiseSetParameters.includeTxPowerLevel,
        'duration': advertiseSetParameters.duration,
        'maxExtendedAdvertisingEvents':
            advertiseSetParameters.maxExtendedAdvertisingEvents
      });
    } else {
      advertiseSettings ??= AdvertiseSettings();
      parameters.addAll({
        'advertiseMode': advertiseSettings.advertiseMode.index,
        'connectable': advertiseSettings.connectable,
        'timeout': advertiseSettings.timeout,
        'txPowerLevel': advertiseSettings.txPowerLevel.index,
      });
    }

    if (advertiseResponseData != null) {
      parameters.addAll({
        'periodicServiceUuid': advertiseData.serviceUuid,
        'periodicManufacturerId': advertiseData.manufacturerId,
        'periodicManufacturerData': advertiseData.manufacturerData,
        'periodicServiceDataUuid': advertiseData.serviceDataUuid,
        'periodicServiceData': advertiseData.serviceData,
        'periodicIncludeDeviceName': advertiseData.includeDeviceName,
        'periodicTransmissionPowerIncluded': advertiseData.includePowerLevel,
        'periodicServiceSolicitationUuid':
            advertiseData.serviceSolicitationUuid,
        // 'periodicServiceSolicitationUuid': da, TODO: interval
      });
    }

    return _methodChannel.invokeMethod('start', parameters);
  }

  /// Stop advertising
  Future<void> stop() async {
    return _methodChannel.invokeMethod('stop');
  }

  /// Returns `true` if advertising or false if not advertising
  Future<bool> get isAdvertising async {
    return await _methodChannel.invokeMethod<bool>('isAdvertising') ?? false;
  }

  /// Returns `true` if advertising over BLE is supported
  Future<bool> get isSupported async =>
      await _methodChannel.invokeMethod<bool>('isSupported') ?? false;

  /// Returns `true` if device is connected
  Future<bool> get isConnected async =>
      await _methodChannel.invokeMethod<bool>('isConnected') ?? false;

  /// Start advertising. Takes [AdvertiseData] as an input.
  Future<void> sendData(Uint8List data) async {
    await _methodChannel.invokeMethod('sendData', data);
  }

  /// Stop advertising
  ///
  /// [askUser] ONLY AVAILABLE ON ANDROID SDK < 33
  /// If set to false, it will enable bluetooth without asking user.
  Future<bool> enableBluetooth({bool askUser = true}) async {
    return await _methodChannel.invokeMethod<bool>(
          'enableBluetooth',
          askUser,
        ) ??
        false;
  }

  /// Returns Stream of MTU updates.
  Stream<int> get onMtuChanged {
    _mtuState ??= _mtuChangedEventChannel
        .receiveBroadcastStream()
        .cast<int>()
        .distinct()
        .map((dynamic event) => event as int);
    return _mtuState!;
  }

  /// Returns Stream of state.
  ///
  /// After listening to this Stream, you'll be notified about changes in peripheral state.
  Stream<PeripheralState> get onPeripheralStateChanged {
    _peripheralState ??= _stateChangedEventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => PeripheralState.values[event as int]);
    return _peripheralState!;
  }

  // /// Returns Stream of data.
  // ///
  // ///
  // Stream<Uint8List> getDataReceived() {
  //   return _dataReceivedEventChannel.receiveBroadcastStream().cast<Uint8List>();
  // }
}
