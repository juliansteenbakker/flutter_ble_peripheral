/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:json_annotation/json_annotation.dart';

part 'windows_advertise_settings.g.dart';

/// Windows-specific advertising settings.
///
/// This class maps to Windows Runtime's BluetoothLEAdvertisement API. These
/// settings are used with BluetoothLEAdvertisementPublisher.
///
/// Reference:
/// https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.advertisement.bluetoothleadvertisement
@JsonSerializable()
class WindowsAdvertiseSettings {
  /// Creates the Windows advertising settings.
  const WindowsAdvertiseSettings({
    this.timeout = 0,
    this.flags,
    this.useExtendedAdvertisement = false,
    this.preferredTransmitPowerLevel,
  });

  /// Creates settings from the map [toJson] produces.
  factory WindowsAdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$WindowsAdvertiseSettingsFromJson(json);

  /// Limit advertising to a given amount of time in milliseconds.
  ///
  /// Zero, the default, leaves the advertisement up until `stop` is called.
  ///
  /// The Android equivalent is `AdvertiseSettings.timeout`, which applies on
  /// the legacy path only. This one applies on the extended path too, since a
  /// Windows publisher has no per-set duration to end it instead.
  final int timeout;

  /// Bluetooth LE advertisement flags.
  ///
  /// Flags control the discoverability and capability modes.
  ///
  /// Common flag values:
  /// - 0x01: LE Limited Discoverable Mode
  /// - 0x02: LE General Discoverable Mode
  /// - 0x04: BR/EDR Not Supported
  /// - 0x08: Simultaneous LE and BR/EDR Controller
  /// - 0x10: Simultaneous LE and BR/EDR Host
  ///
  /// Maps to `BluetoothLEAdvertisement.Flags`
  final int? flags;

  /// Use extended advertisement format.
  ///
  /// If true, uses the extended advertisement format which allows:
  /// - Larger data payloads
  /// - Better performance with multiple concurrent advertisements
  /// - Support for advertising on secondary PHY channels
  ///
  /// Requires Windows 10 version 1809 (Build 17763) or later.
  ///
  /// Default: false
  final bool useExtendedAdvertisement;

  /// Preferred transmission power level in dBm.
  ///
  /// This is a hint to the system about the desired transmission power. Actual
  /// power used may differ based on hardware capabilities.
  ///
  /// Typical values:
  /// - High: 4 dBm
  /// - Medium: 0 dBm
  /// - Low: -10 dBm
  /// - Ultra Low: -20 dBm
  ///
  /// Default: null (system decides)
  final int? preferredTransmitPowerLevel;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$WindowsAdvertiseSettingsToJson(this);

  /// Creates a copy with optional field replacements
  WindowsAdvertiseSettings copyWith({
    int? timeout,
    int? flags,
    bool? useExtendedAdvertisement,
    int? preferredTransmitPowerLevel,
  }) {
    return WindowsAdvertiseSettings(
      timeout: timeout ?? this.timeout,
      flags: flags ?? this.flags,
      useExtendedAdvertisement:
          useExtendedAdvertisement ?? this.useExtendedAdvertisement,
      preferredTransmitPowerLevel:
          preferredTransmitPowerLevel ?? this.preferredTransmitPowerLevel,
    );
  }
}
