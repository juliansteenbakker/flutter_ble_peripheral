/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';
import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/src/models/advertise_data.dart';
import 'package:flutter_ble_peripheral/src/models/advertise_set_parameters.dart';
import 'package:flutter_ble_peripheral/src/models/advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/models/enums/bluetooth_peripheral_state.dart';
import 'package:flutter_ble_peripheral/src/models/periodic_advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/models/peripheral_state.dart';
import 'package:flutter_ble_peripheral/src/models/permission_state.dart';

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
  Future<BluetoothPeripheralState> start({
    required AdvertiseData advertiseData,
    AdvertiseSettings? advertiseSettings,
    AdvertiseSetParameters? advertiseSetParameters,
    AdvertiseData? advertiseResponseData,
    AdvertiseData? advertisePeriodicData,
    PeriodicAdvertiseSettings? periodicAdvertiseSettings,
  }) async {

    final parameters = advertiseData.toJson();
    parameters["manufacturerDataBytes"] = advertiseData.manufacturerData;
    final settings = advertiseSettings ?? AdvertiseSettings();
    final jsonSettings = settings.toJson();
    for (final key in jsonSettings.keys) {
      parameters[key] = jsonSettings[key];
    }
    parameters.addAll(advertiseData.toJson());

    if (advertiseSetParameters != null) {
      final json = advertiseSetParameters.toJson();
      for (final key in json.keys) {
        parameters['set$key'] = json[key];
      }
      parameters.addAll(advertiseData.toJson());
    }

    if (advertiseResponseData != null) {
      final json = advertiseData.toJson();
      for (final key in json.keys) {
        parameters['response$key'] = json[key];
      }
      parameters.addAll(advertiseData.toJson());
    }

    final response =
        await _methodChannel.invokeMethod<int>('start', parameters);
    return response == null
        ? BluetoothPeripheralState.unknown
        : BluetoothPeripheralState.values[response];
  }

  /// Stop advertising
  Future<BluetoothPeripheralState> stop() async {
    final response = await _methodChannel.invokeMethod<int>('stop');
    return response == null
        ? BluetoothPeripheralState.unknown
        : BluetoothPeripheralState.values[response];
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

  Future<BluetoothPeripheralState> requestPermission() async {
    final response =
        await _methodChannel.invokeMethod<int>('requestPermissions');
    return response == null
        ? BluetoothPeripheralState.unknown
        : BluetoothPeripheralState.values[response];
  }

  Future<BluetoothPeripheralState> hasPermission() async {
    final response = await _methodChannel.invokeMethod<int>('hasPermission');
    return response == null
        ? BluetoothPeripheralState.unknown
        : BluetoothPeripheralState.values[response];
  }

  Future<void> openBluetoothSettings() async {
    await _methodChannel.invokeMethod('openBluetoothSettings');
  }

  Future<void> openAppSettings() async {
    await _methodChannel.invokeMethod('openAppSettings');
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
  Stream<PeripheralState>? get onPeripheralStateChanged {
    if (Platform.isWindows) return null;
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
