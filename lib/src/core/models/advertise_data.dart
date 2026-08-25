/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter_ble_peripheral/src/core/models/advertise_data_core.dart';
import 'package:flutter_ble_peripheral/src/core/utils/uint8list_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advertise_data.g.dart';

/// Model of the data to be advertised.
///
/// **DEPRECATED**: This class mixes Android-specific fields with cross-platform
/// fields. For new code, use:
/// - [AdvertiseDataCore] for cross-platform advertising data
/// - `AndroidAdvertiseData` for Android-specific fields
/// - `DarwinAdvertiseSettings` for iOS/macOS-specific settings
/// - `WindowsAdvertiseSettings` for Windows-specific settings
@Deprecated(
  'Use AdvertiseDataCore for cross-platform data, or platform-specific classes '
  '(AndroidAdvertiseData, DarwinAdvertiseSettings, WindowsAdvertiseSettings) '
  'for platform-specific features. This class will be removed in a future '
  'version.',
)
@JsonSerializable()
class AdvertiseData extends AdvertiseDataCore {
  /// Creates the data to advertise.
  @Deprecated(
    'Use AdvertiseDataCore or AndroidAdvertiseData instead. '
    'This constructor will be removed in a future version.',
  )
  AdvertiseData({
    super.serviceUuid,
    super.serviceUuids,
    super.manufacturerId,
    super.manufacturerData,
    this.serviceDataUuid,
    this.serviceData,
    this.includeDeviceName = false,
    super.localName,
    bool includePowerLevel = false,
    bool includeTxPowerLevel = false,
    this.serviceSolicitationUuid,
  }) : super(
          includeTxPowerLevel: includeTxPowerLevel || includePowerLevel,
        );

  /// Creates advertise data from the map [toJson] produces.
  @Deprecated(
    'Use AdvertiseDataCore.fromJson or AndroidAdvertiseData.fromJson instead. '
    'This factory will be removed in a future version.',
  )
  factory AdvertiseData.fromJson(Map<String, dynamic> json) =>
      _$AdvertiseDataFromJson(json);

  /// Android only
  ///
  /// Specifies service data UUID
  final String? serviceDataUuid;

  /// Android only
  ///
  /// Specifies service data
  final List<int>? serviceData;

  /// Android only
  ///
  /// Set to true if device name needs to be included with advertisement
  /// Default: false
  final bool includeDeviceName;

  /// Android only
  ///
  /// Set to true if you want to include the transmission power level in the
  /// advertisement. Default: false
  ///
  /// Renamed to `includeTxPowerLevel` on [AdvertiseDataCore], which every
  /// platform that supports it now reads.
  @JsonKey(includeToJson: false, includeFromJson: false)
  bool get includePowerLevel => includeTxPowerLevel;

  /// Android > SDK 31 only
  ///
  /// A service solicitation UUID to advertise data.
  final String? serviceSolicitationUuid;

  /// The map sent over the method channel to the platform.
  @override
  Map<String, dynamic> toJson() => _$AdvertiseDataToJson(this);
}
