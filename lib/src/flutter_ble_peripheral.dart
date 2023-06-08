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
import 'package:flutter_ble_peripheral/src/models/message_packet.dart';
import 'package:flutter_ble_peripheral/src/models/periodic_advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/models/peripheral_state.dart';
import 'package:flutter_ble_peripheral/src/models/permission_state.dart';

import 'package:flutter_ble_peripheral/src/models/service_description.dart';

class FlutterBlePeripheral {
  /// Singleton instance
  static final FlutterBlePeripheral _instance =
      FlutterBlePeripheral._internal();

  /// Singleton factory
  factory FlutterBlePeripheral() {
    return _instance;
  }


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

  /// Event Channel for received data
  final EventChannel _dataReceivedEventChannel = const EventChannel(
    'dev.steenbakker.flutter_ble_peripheral/ble_data_received',
  );

  late final Stream<int> _mtuState;
  late final Stream<PeripheralState>? _peripheralState;
  late final Stream<MessagePacket> _dataReceived;

  PeripheralState? _state;
  int? _mtu;

  /// Singleton constructor
  FlutterBlePeripheral._internal() {
    _dataReceived = _dataReceivedEventChannel.receiveBroadcastStream()
        .cast<Map<dynamic,dynamic>>()
        .map((event) => MessagePacket.fromMap(Map<String,dynamic>.from(event)));

    _mtuState = _mtuChangedEventChannel.receiveBroadcastStream()
        .cast<int>()
        .distinct()
        .map((dynamic event) => (event as int) - 3); // Subtract 3 bytes taken up by the header
    _mtuState.listen((mtu) => _mtu = mtu);

    if (Platform.isWindows) {
      _peripheralState = null;
    } else {
      _peripheralState = _stateChangedEventChannel.receiveBroadcastStream()
          .map((dynamic event) => PeripheralState.values[event as int]);
      _peripheralState!.listen((s) => _state = s);
    }
  }



  Future<void> addService(ServiceDescription service) async {
    return _methodChannel.invokeMethod('addService', service.toMap());
  }

  Future<void> removeService(String serviceUUID) async {
    return _methodChannel.invokeMethod('removeService', serviceUUID);
  }

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
  Future<void> stop() async {
    await _methodChannel.invokeMethod<int>('stop');
  }

  PeripheralState get state {
    return _state ?? PeripheralState.unknown;
  }

  /// Returns `true` if advertising or false if not advertising
  bool get isAdvertising  =>
    state == PeripheralState.advertising;

  /// Returns `true` if advertising over BLE is supported
  bool get isSupported =>
      state != PeripheralState.unsupported;

  /// Returns `true` if device is connected
  bool get isConnected =>
      state == PeripheralState.connected;

  /// Returns the current Minimum Transmission Unit of the connection
  /// This corresponds to the ATT MTU minus 3, since the header of an ATT package takes up 3 bytes
  /// Default (if the client doesn't negotiate another) is 20
  int get mtu {
    return _mtu ?? -1;
  }

  /// Reads the current value of a descriptor. Returns null if no such descriptor exists
  Future<Uint8List?> read(String characteristicUUID) {
    return _methodChannel.invokeMethod<Uint8List>('read', characteristicUUID);
  }

  /// Writes the value of a descriptor and notifies subscribed devices
  Future<void> write(String characteristicUUID, Uint8List data) async {
    final Map<String, dynamic> parameters = {
      "characteristic": characteristicUUID,
      "data": data
    };
    await _methodChannel.invokeMethod('write', parameters);
  }


  /// [askUser] ONLY AVAILABLE ON ANDROID SDK < 33
  /// If set to false, it will enable bluetooth without asking user.
  Future<bool> enableBluetooth({bool askUser = true}) async {
    return await _methodChannel.invokeMethod<bool>(
          'enableBluetooth',
          askUser,
        ) ??
        false;
  }

  Future<PermissionState> requestPermission() async {
    final response =
        await _methodChannel.invokeMethod<int>('requestPermissions');
    return response == null
        ? PermissionState.unknown
        : PermissionState.values[response];
  }

  Future<PermissionState> hasPermission() async {
    final response = await _methodChannel.invokeMethod<int>('hasPermission');
    return response == null
        ? PermissionState.unknown
        : PermissionState.values[response];
  }

  Future<void> openBluetoothSettings() async {
    await _methodChannel.invokeMethod('openBluetoothSettings');
  }

  Future<void> openAppSettings() async {
    await _methodChannel.invokeMethod('openAppSettings');
  }

  /// Returns Stream of MTU updates.
  Stream<int> get onMtuChanged => _mtuState;

  /// Returns Stream of state.
  ///
  /// After listening to this Stream, you'll be notified about changes in peripheral state.
  Stream<PeripheralState>? get onPeripheralStateChanged => _peripheralState;

  /// Returns Stream of data.
  ///
  ///
  Stream<MessagePacket> get getDataReceived => _dataReceived;
}
