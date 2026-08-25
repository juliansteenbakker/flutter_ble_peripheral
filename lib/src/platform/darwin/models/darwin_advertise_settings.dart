/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:json_annotation/json_annotation.dart';

part 'darwin_advertise_settings.g.dart';

/// Darwin (iOS/macOS) specific advertising settings.
///
/// This class maps to CoreBluetooth's CBPeripheralManager advertising options.
/// These settings are passed to `peripheralManager.startAdvertising(_:)`.
///
/// CoreBluetooth only lets an app advertise a local name and service UUIDs,
/// both of which live on `AdvertiseDataCore`, plus the two UUID lists below.
/// Manufacturer data and service data cannot be advertised by a third-party
/// app, so they are not offered here.
///
/// Reference:
/// https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager
@JsonSerializable()
class DarwinAdvertiseSettings {
  /// Creates the iOS/macOS advertising settings.
  const DarwinAdvertiseSettings({
    this.overflowServiceUuids,
    this.solicitedServiceUuids,
  });

  /// Creates settings from the map [toJson] produces.
  factory DarwinAdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$DarwinAdvertiseSettingsFromJson(json);

  /// Overflow service UUIDs.
  ///
  /// Maps to `CBAdvertisementDataOverflowServiceUUIDsKey`.
  ///
  /// Service UUIDs that don't fit in the main advertisement packet but should
  /// still be discoverable via a scan response.
  ///
  /// iOS automatically handles overflow for you in most cases.
  final List<String>? overflowServiceUuids;

  /// Solicited service UUIDs.
  ///
  /// Maps to `CBAdvertisementDataSolicitedServiceUUIDsKey`.
  ///
  /// Service UUIDs that this peripheral is interested in connecting to. This
  /// can help centrals prioritise discovery based on their services.
  ///
  /// The Android equivalent is
  /// `AndroidAdvertiseData.serviceSolicitationUuid`, which takes a single UUID
  /// and needs Android 12 or above.
  final List<String>? solicitedServiceUuids;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$DarwinAdvertiseSettingsToJson(this);

  /// Creates a copy with optional field replacements.
  DarwinAdvertiseSettings copyWith({
    List<String>? overflowServiceUuids,
    List<String>? solicitedServiceUuids,
  }) {
    return DarwinAdvertiseSettings(
      overflowServiceUuids: overflowServiceUuids ?? this.overflowServiceUuids,
      solicitedServiceUuids:
          solicitedServiceUuids ?? this.solicitedServiceUuids,
    );
  }
}
