/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:typed_data';

import 'package:flutter_ble_peripheral/src/core/utils/uint8list_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advertise_data_core.g.dart';

/// Core cross-platform advertising data model.
///
/// This class carries the fields that more than one platform can advertise.
/// For anything a single platform supports, use the corresponding platform
/// class:
/// - Android: `AndroidAdvertiseData`, `AndroidAdvertiseSettings`
/// - iOS/macOS: `DarwinAdvertiseSettings`
/// - Windows: `WindowsAdvertiseSettings`
@JsonSerializable()
class AdvertiseDataCore {
  /// Creates the cross-platform data to advertise.
  const AdvertiseDataCore({
    this.serviceUuid,
    this.serviceUuids,
    this.localName,
    this.manufacturerId,
    this.manufacturerData,
    this.includeTxPowerLevel = false,
  });

  /// Creates advertise data from the map [toJson] produces.
  factory AdvertiseDataCore.fromJson(Map<String, dynamic> json) =>
      _$AdvertiseDataCoreFromJson(json);

  /// Specifies a single service UUID to be advertised.
  ///
  /// Supported on all platforms. If [serviceUuids] is specified, this field may
  /// be ignored depending on the platform.
  final String? serviceUuid;

  /// Specifies multiple service UUIDs to be advertised.
  ///
  /// If specified, [serviceUuid] may be used as a fallback on some platforms.
  ///
  /// Each entry may be a 128 bit UUID (dashed or undashed), or a 16 bit
  /// ("A1B2") or 32 bit ("A1B2C3D4") short form resolved against the Bluetooth
  /// Base UUID and advertised as a compact 16 or 32 bit service UUID.
  final List<String>? serviceUuids;

  /// The local name to broadcast.
  ///
  /// Platform-specific behaviour:
  /// - iOS/macOS: sets `CBAdvertisementDataLocalNameKey`, where at most 10
  ///   bytes are recommended
  /// - Android: does not work, use `AndroidAdvertiseData.includeDeviceName`
  /// - Windows: sets the local name in the advertisement
  final String? localName;

  /// The manufacturer ID assigned by the Bluetooth SIG.
  ///
  /// Must be set together with [manufacturerData].
  ///
  /// Supported on Android and Windows. iOS and macOS do not let an app put
  /// manufacturer data in an advertisement, so this is ignored there.
  final int? manufacturerId;

  /// The manufacturer specific data to advertise, belonging to
  /// [manufacturerId].
  ///
  /// Supported on Android and Windows. iOS and macOS do not let an app put
  /// manufacturer data in an advertisement, so this is ignored there.
  @Uint8ListConverter()
  final Uint8List? manufacturerData;

  /// Whether to include the transmission power level in the advertisement.
  ///
  /// Supported on Android and Windows. iOS and macOS do not expose this, so it
  /// is ignored there.
  ///
  /// Default: false
  final bool includeTxPowerLevel;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$AdvertiseDataCoreToJson(this);

  /// Creates a copy with optional field replacements.
  AdvertiseDataCore copyWith({
    String? serviceUuid,
    List<String>? serviceUuids,
    String? localName,
    int? manufacturerId,
    Uint8List? manufacturerData,
    bool? includeTxPowerLevel,
  }) {
    return AdvertiseDataCore(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      localName: localName ?? this.localName,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      manufacturerData: manufacturerData ?? this.manufacturerData,
      includeTxPowerLevel: includeTxPowerLevel ?? this.includeTxPowerLevel,
    );
  }
}
