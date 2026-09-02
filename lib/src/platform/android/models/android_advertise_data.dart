/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:typed_data';

import 'package:flutter_ble_peripheral/src/core/models/advertise_data_core.dart';
import 'package:flutter_ble_peripheral/src/core/utils/uint8list_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'android_advertise_data.g.dart';

/// Android-specific advertising data model.
///
/// This class extends [AdvertiseDataCore] with Android-specific fields that map
/// directly to Android's `AdvertiseData.Builder` API.
///
/// For Android advertising settings (mode, timeout, tx power), use
/// `AdvertiseSettings`. For extended advertising (Android 8+), use
/// `AdvertiseSetParameters`.
@JsonSerializable()
class AndroidAdvertiseData extends AdvertiseDataCore {
  /// Creates the Android advertising data.
  const AndroidAdvertiseData({
    // Core fields
    super.serviceUuid,
    super.serviceUuids,
    super.localName,
    super.manufacturerId,
    super.manufacturerData,
    super.includeTxPowerLevel,
    // Android-specific fields
    this.serviceDataUuid,
    this.serviceData,
    this.includeDeviceName = false,
    this.serviceSolicitationUuid,
  });

  /// Creates advertise data from the map [toJson] produces.
  factory AndroidAdvertiseData.fromJson(Map<String, dynamic> json) =>
      _$AndroidAdvertiseDataFromJson(json);

  /// Creates Android advertising data from cross-platform [AdvertiseDataCore].
  factory AndroidAdvertiseData.fromCore(AdvertiseDataCore core) {
    return AndroidAdvertiseData(
      serviceUuid: core.serviceUuid,
      serviceUuids: core.serviceUuids,
      localName: core.localName,
      manufacturerId: core.manufacturerId,
      manufacturerData: core.manufacturerData,
      includeTxPowerLevel: core.includeTxPowerLevel,
    );
  }

  /// Specifies service data UUID.
  ///
  /// Must be used together with [serviceData].
  ///
  /// Android API: `AdvertiseData.Builder.addServiceData(serviceDataUuid,
  /// serviceData)`
  final String? serviceDataUuid;

  /// Specifies service data payload.
  ///
  /// Must be used together with [serviceDataUuid].
  ///
  /// Android API: `AdvertiseData.Builder.addServiceData(serviceDataUuid,
  /// serviceData)`
  final List<int>? serviceData;

  /// Set to true if device name needs to be included with advertisement.
  ///
  /// Default: false
  ///
  /// Note: Including the device name reduces the available space for other
  /// data. On Android, the default device name is typically the device model.
  ///
  /// Android API:
  /// `AdvertiseData.Builder.setIncludeDeviceName(includeDeviceName)`
  final bool includeDeviceName;

  /// A service solicitation UUID to advertise.
  ///
  /// Android SDK 31 (Android 12) and above only.
  ///
  /// Service solicitation UUIDs indicate which services the peripheral is
  /// interested in connecting to, which can improve discovery performance.
  ///
  /// Android API:
  /// `AdvertiseData.Builder.addServiceSolicitationUuid(parcelUuid)`
  final String? serviceSolicitationUuid;

  @override

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$AndroidAdvertiseDataToJson(this);

  /// Creates a copy with optional field replacements
  @override
  AndroidAdvertiseData copyWith({
    String? serviceUuid,
    List<String>? serviceUuids,
    String? localName,
    int? manufacturerId,
    Uint8List? manufacturerData,
    bool? includeTxPowerLevel,
    String? serviceDataUuid,
    List<int>? serviceData,
    bool? includeDeviceName,
    String? serviceSolicitationUuid,
  }) {
    return AndroidAdvertiseData(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      localName: localName ?? this.localName,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      manufacturerData: manufacturerData ?? this.manufacturerData,
      includeTxPowerLevel: includeTxPowerLevel ?? this.includeTxPowerLevel,
      serviceDataUuid: serviceDataUuid ?? this.serviceDataUuid,
      serviceData: serviceData ?? this.serviceData,
      includeDeviceName: includeDeviceName ?? this.includeDeviceName,
      serviceSolicitationUuid:
          serviceSolicitationUuid ?? this.serviceSolicitationUuid,
    );
  }
}
