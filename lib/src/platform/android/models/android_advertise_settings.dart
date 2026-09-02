/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter_ble_peripheral/src/platform/android/models/advertise_set_parameters.dart';
import 'package:flutter_ble_peripheral/src/platform/android/models/advertise_settings.dart';
import 'package:flutter_ble_peripheral/src/platform/android/models/android_advertise_data.dart';
import 'package:flutter_ble_peripheral/src/platform/android/models/periodic_advertise_settings.dart';
import 'package:json_annotation/json_annotation.dart';

part 'android_advertise_settings.g.dart';

/// Android advertising settings that directly map to Android's native API.
///
/// This class mirrors the Android BluetoothLeAdvertiser API structure:
/// - **Legacy advertising** (pre-Android 8): Uses [advertiseSettings]
/// - **Extended advertising** (Android 8+): Uses [advertiseSetParameters]
///
/// Reference:
/// https://developer.android.com/reference/android/bluetooth/le/BluetoothLeAdvertiser
@JsonSerializable()
class AndroidAdvertiseSettings {
  /// Creates the Android advertising settings.
  const AndroidAdvertiseSettings({
    this.advertiseSettings,
    this.advertiseSetParameters,
    this.advertiseResponseData,
    this.periodicAdvertiseData,
    this.periodicAdvertiseSettings,
  }) : assert(
          advertiseSettings == null || advertiseSetParameters == null,
          'Cannot use both advertiseSettings and advertiseSetParameters. '
          'Use advertiseSettings for legacy advertising (Android < 8) or '
          'advertiseSetParameters for extended advertising (Android 8+).',
        );

  /// Creates settings from the map [toJson] produces.
  factory AndroidAdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$AndroidAdvertiseSettingsFromJson(json);

  // ========== Legacy Advertising (pre-Android 8) ==========

  /// Legacy advertising settings.
  ///
  /// Maps to `AdvertiseSettings.Builder` in Android native code. Used when NOT
  /// using extended advertising (Android < 8 or when extended is not needed).
  ///
  /// If both [advertiseSettings] and [advertiseSetParameters] are null,
  /// defaults to legacy advertising with default settings.
  ///
  /// Android API: `startAdvertising(AdvertiseSettings, AdvertiseData,
  /// AdvertiseCallback)`
  final AdvertiseSettings? advertiseSettings;

  // ========== Extended Advertising (Android 8+) ==========

  /// Extended advertising parameters (Android 8+).
  ///
  /// Maps to `AdvertisingSetParameters.Builder` in Android native code. When
  /// provided, uses the extended advertising API instead of legacy.
  ///
  /// Provides advanced features:
  /// - Larger data payloads
  /// - Multiple concurrent advertisements
  /// - Secondary PHY channels
  /// - Periodic advertising support
  ///
  /// Android API: `startAdvertisingSet(AdvertisingSetParameters, AdvertiseData,
  /// ...)`
  ///
  /// Requires Android 8.0 (API level 26) or higher.
  final AdvertiseSetParameters? advertiseSetParameters;

  // ========== Scan Response Data ==========

  /// Scan response data (optional).
  ///
  /// Additional advertising data sent in response to scan requests. Useful when
  /// the main advertising packet is full.
  ///
  /// Maps to the `scanResponse` parameter in:
  /// - Legacy: `startAdvertising(..., scanResponse, ...)`
  /// - Extended: `startAdvertisingSet(..., scanResponse, ...)`
  ///
  /// **Important**: Uses [AndroidAdvertiseData] to support all Android
  /// AdvertiseData fields
  /// including manufacturer data, service data, service solicitation UUIDs,
  /// etc.
  ///
  /// Android API: Second `AdvertiseData` parameter
  final AndroidAdvertiseData? advertiseResponseData;

  // ========== Periodic Advertising (Android 8+) ==========

  /// Periodic advertising data.
  ///
  /// Data to broadcast periodically after initial advertising. Only used with
  /// extended advertising ([advertiseSetParameters] must be set).
  ///
  /// Maps to `periodicData` parameter in `startAdvertisingSet()`.
  ///
  /// **Important**: Uses [AndroidAdvertiseData] to support all Android
  /// AdvertiseData fields
  /// including manufacturer data, service data, service solicitation UUIDs,
  /// etc.
  ///
  /// Android API: `startAdvertisingSet(..., periodicData, periodicParameters,
  /// ...)`
  final AndroidAdvertiseData? periodicAdvertiseData;

  /// Periodic advertising parameters.
  ///
  /// Controls the interval and TX power for periodic advertising. Only used
  /// when [periodicAdvertiseData] is provided.
  ///
  /// Maps to `PeriodicAdvertisingParameters.Builder` in Android native code.
  ///
  /// Android API: `PeriodicAdvertisingParameters` in `startAdvertisingSet()`
  final PeriodicAdvertiseSettings? periodicAdvertiseSettings;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$AndroidAdvertiseSettingsToJson(this);

  /// Creates a copy with optional field replacements
  AndroidAdvertiseSettings copyWith({
    AdvertiseSettings? advertiseSettings,
    AdvertiseSetParameters? advertiseSetParameters,
    AndroidAdvertiseData? advertiseResponseData,
    AndroidAdvertiseData? periodicAdvertiseData,
    PeriodicAdvertiseSettings? periodicAdvertiseSettings,
  }) {
    return AndroidAdvertiseSettings(
      advertiseSettings: advertiseSettings ?? this.advertiseSettings,
      advertiseSetParameters:
          advertiseSetParameters ?? this.advertiseSetParameters,
      advertiseResponseData:
          advertiseResponseData ?? this.advertiseResponseData,
      periodicAdvertiseData:
          periodicAdvertiseData ?? this.periodicAdvertiseData,
      periodicAdvertiseSettings:
          periodicAdvertiseSettings ?? this.periodicAdvertiseSettings,
    );
  }

  /// Check if using extended advertising API.
  ///
  /// Returns true if [advertiseSetParameters] is set, indicating the extended
  /// advertising API (Android 8+) should be used.
  bool get isUsingExtendedAdvertising => advertiseSetParameters != null;
}
