/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';
import 'dart:io';
// Uint8List is part of the public API here, so it is imported explicitly
// rather than relying on it leaking in through flutter/services.dart.
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/src/core/enums/peripheral_bluetooth_state.dart';
import 'package:flutter_ble_peripheral/src/core/enums/peripheral_state.dart';
import 'package:flutter_ble_peripheral/src/core/models/advertise_data_core.dart';
import 'package:flutter_ble_peripheral/src/platform/android/models/android_advertise_data.dart';
import 'package:flutter_ble_peripheral/src/platform/android/models/android_advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/platform/darwin/models/darwin_advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/platform/windows/models/windows_advertise_settings.dart';

/// Advertises this device as a BLE peripheral, and serves the GATT service
/// that connected centrals read from and write to.
class FlutterBlePeripheral {
  /// Returns the singleton instance.
  factory FlutterBlePeripheral() {
    return _instance;
  }

  FlutterBlePeripheral._internal();

  /// Singleton instance
  static final FlutterBlePeripheral _instance =
      FlutterBlePeripheral._internal();

  /// Method Channel used to communicate state with
  static const MethodChannel _methodChannel = MethodChannel(
    'dev.steenbakker.flutter_ble_peripheral/ble_state',
  );

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

  /// Start advertising.
  ///
  /// [advertiseData] - Core advertising data. Use [AdvertiseDataCore] for
  /// cross-platform, or platform-specific classes like [AndroidAdvertiseData]
  /// for platform features.
  ///
  /// Platform-specific settings:
  /// - Android: [androidSettings]
  /// - iOS/macOS: [darwinSettings]
  /// - Windows: [windowsSettings]
  ///
  /// For backward compatibility, the deprecated `AdvertiseData` is also
  /// accepted.
  ///
  /// Returns [PeripheralBluetoothState.ready] once the advertisement is on air.
  /// On Apple platforms a state such as [PeripheralBluetoothState.turnedOff] is
  /// returned when the radio is not up yet; the advertisement is queued and
  /// starts as soon as it is. A platform that refuses the advertisement
  /// outright throws a [PlatformException] instead.
  Future<PeripheralBluetoothState> start({
    required AdvertiseDataCore advertiseData,

    // Platform-specific settings
    AndroidAdvertiseSettings? androidSettings,
    DarwinAdvertiseSettings? darwinSettings,
    WindowsAdvertiseSettings? windowsSettings,
  }) async {
    final parameters = advertiseData.toJson();

    // The bytes are sent raw as well, so the native side can read a byte
    // buffer rather than decoding the converter's int list.
    if (advertiseData.manufacturerData != null) {
      parameters['manufacturerDataBytes'] = advertiseData.manufacturerData;
    }

    if (advertiseData.serviceUuids != null) {
      parameters['serviceUuids'] = advertiseData.serviceUuids;
    }

    // Android settings
    if (Platform.isAndroid && androidSettings != null) {
      // Automatically set the advertiseSet flag based on which parameters
      // are provided.
      final useExtendedAdvertising =
          androidSettings.advertiseSetParameters != null;
      parameters['advertiseSet'] = useExtendedAdvertising;

      // Legacy advertising settings
      if (androidSettings.advertiseSettings != null) {
        final json = androidSettings.advertiseSettings!.toJson();
        for (final key in json.keys) {
          parameters[key] = json[key];
        }
      }

      // Extended advertising parameters (advertiseSetParameters)
      if (androidSettings.advertiseSetParameters != null) {
        final json = androidSettings.advertiseSetParameters!.toJson();
        for (final key in json.keys) {
          parameters['set$key'] = json[key];
        }
      }

      // Scan response data (advertiseResponseData)
      if (androidSettings.advertiseResponseData != null) {
        final responseData = androidSettings.advertiseResponseData!;
        final json = responseData.toJson();
        for (final key in json.keys) {
          parameters['response$key'] = json[key];
        }

        // Handle manufacturer data bytes separately for response data
        if (responseData.manufacturerData != null) {
          parameters['responsemanufacturerDataBytes'] =
              responseData.manufacturerData;
        }
      }

      // Periodic advertising data
      if (androidSettings.periodicAdvertiseData != null) {
        final periodicData = androidSettings.periodicAdvertiseData!;
        final json = periodicData.toJson();
        for (final key in json.keys) {
          parameters['periodic$key'] = json[key];
        }

        // Handle manufacturer data bytes separately for periodic data
        if (periodicData.manufacturerData != null) {
          parameters['periodicmanufacturerDataBytes'] =
              periodicData.manufacturerData;
        }
      }

      // Periodic advertising settings
      if (androidSettings.periodicAdvertiseSettings != null) {
        final json = androidSettings.periodicAdvertiseSettings!.toJson();
        for (final key in json.keys) {
          parameters['periodicsettings$key'] = json[key];
        }
      }
    }

    // Darwin (iOS/macOS) settings
    if ((Platform.isIOS || Platform.isMacOS) && darwinSettings != null) {
      final darwinJson = darwinSettings.toJson();
      for (final key in darwinJson.keys) {
        parameters['darwin$key'] = darwinJson[key];
      }
    }

    // Windows settings
    if (Platform.isWindows && windowsSettings != null) {
      final windowsJson = windowsSettings.toJson();
      for (final key in windowsJson.keys) {
        parameters['windows$key'] = windowsJson[key];
      }
    }

    final response = await _methodChannel.invokeMethod<int>(
      'start',
      parameters,
    );
    return response == null
        ? PeripheralBluetoothState.unknown
        : PeripheralBluetoothState.values[response];
  }

  /// Stop advertising.
  ///
  /// Returns [PeripheralBluetoothState.ready], since the adapter is free to
  /// advertise again.
  Future<PeripheralBluetoothState> stop() async {
    final response = await _methodChannel.invokeMethod<int>('stop');
    return response == null
        ? PeripheralBluetoothState.unknown
        : PeripheralBluetoothState.values[response];
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

  /// Returns `true` if Bluetooth is turned on.
  ///
  /// On Windows, checks the Bluetooth radio state.
  Future<bool> get isBluetoothOn async =>
      await _methodChannel.invokeMethod<bool>('isBluetoothOn') ?? false;

  /// Send data to the connected centrals over the GATT server.
  Future<void> sendData(Uint8List data) async {
    await _methodChannel.invokeMethod('sendData', data);
  }

  /// Enable Bluetooth programmatically.
  ///
  /// [askUser] ONLY AVAILABLE ON ANDROID SDK < 33 If set to false, it will
  /// enable bluetooth without asking user.
  ///
  /// On Windows, this uses the Radio API to turn on Bluetooth. The [askUser]
  /// parameter is ignored on Windows.
  Future<bool> enableBluetooth({bool askUser = true}) async {
    if (Platform.isWindows) {
      return await _methodChannel.invokeMethod<bool>('enableBluetooth') ??
          false;
    }
    if (!Platform.isAndroid) return false;
    return await _methodChannel.invokeMethod<bool>(
          'enableBluetooth',
          askUser,
        ) ??
        false;
  }

  /// Requests the required permissions for BLE advertising.
  ///
  /// On Android, requests Bluetooth permissions. On iOS/macOS, returns current
  /// authorization status (permissions are requested implicitly when
  /// initializing the peripheral manager). On Windows, requests location
  /// permission (required for BLE).
  Future<PeripheralBluetoothState> requestPermission() async {
    if (Platform.isWindows) {
      final granted = await _methodChannel.invokeMethod<bool>(
            'requestLocationPermission',
          ) ??
          false;
      return granted
          ? PeripheralBluetoothState.granted
          : PeripheralBluetoothState.denied;
    }
    final response = await _methodChannel.invokeMethod<int>(
      'requestPermission',
    );
    return response == null
        ? PeripheralBluetoothState.unknown
        : PeripheralBluetoothState.values[response];
  }

  /// Checks if the required permissions for BLE advertising are granted.
  ///
  /// On Android, checks Bluetooth permissions. On iOS/macOS, checks Bluetooth
  /// authorization status. On Windows, checks location permission (required for
  /// BLE).
  Future<PeripheralBluetoothState> hasPermission() async {
    if (Platform.isWindows) {
      final granted =
          await _methodChannel.invokeMethod<bool>('hasLocationPermission') ??
              false;
      return granted
          ? PeripheralBluetoothState.granted
          : PeripheralBluetoothState.denied;
    }
    final response = await _methodChannel.invokeMethod<int>('hasPermission');
    return response == null
        ? PeripheralBluetoothState.unknown
        : PeripheralBluetoothState.values[response];
  }

  /// Opens the system Bluetooth settings.
  Future<void> openBluetoothSettings() async {
    await _methodChannel.invokeMethod('openBluetoothSettings');
  }

  /// Opens this app's settings page.
  Future<void> openAppSettings() async {
    await _methodChannel.invokeMethod('openAppSettings');
  }

  /// Opens the Windows Nearby Sharing settings page.
  ///
  /// This is useful when BLE advertising fails due to Nearby Sharing blocking
  /// the Bluetooth resources (ResourceInUse error). Only works on Windows.
  Future<void> openNearbyShareSettings() async {
    if (!Platform.isWindows) return;
    await _methodChannel.invokeMethod('openNearbyShareSettings');
  }

  /// Checks if Windows Nearby Sharing is enabled.
  ///
  /// Returns `true` if Nearby Sharing is set to "My devices only" or "Everyone
  /// nearby". Returns `false` if it's off or on non-Windows platforms.
  ///
  /// Nearby Sharing can interfere with BLE advertising on Windows.
  Future<bool> isNearbyShareEnabled() async {
    if (!Platform.isWindows) return false;
    return await _methodChannel.invokeMethod<bool>('isNearbyShareEnabled') ??
        false;
  }

  /// Opens the Windows Location privacy settings page.
  ///
  /// Useful when the user has denied location permission and needs to manually
  /// enable it for the app. Only works on Windows.
  Future<void> openLocationSettings() async {
    if (!Platform.isWindows) return;
    await _methodChannel.invokeMethod('openLocationSettings');
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
  /// After listening to this Stream, you'll be notified about changes in
  /// peripheral state.
  Stream<PeripheralState>? get onPeripheralStateChanged {
    _peripheralState ??= _stateChangedEventChannel.receiveBroadcastStream().map(
          (dynamic event) => PeripheralState.values[event as int],
        );
    return _peripheralState!;
  }
}
