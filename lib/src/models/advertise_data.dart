/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:typed_data';

import 'package:flutter_ble_peripheral/src/models/uint8list_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advertise_data.g.dart';

/// Model of the data to be advertised.
@JsonSerializable()
class AdvertiseData {
  /// Android & iOS
  ///
  /// Specifies a single service UUIDs to be advertised
  // @Deprecated(
  //   'Please use serviceUuids, where you can also define a single service uuid.',
  // )
  final String? serviceUuid;

  /// Android, iOS & macOS
  ///
  /// Specifies multiple service UUIDs to be advertised.
  /// If specified, [serviceUuid] will not be used.
  ///
  /// Each entry may be a 128 bit UUID (dashed or undashed), or a 16 bit
  /// ("A1B2") or 32 bit ("A1B2C3D4") short form resolved against the Bluetooth
  /// Base UUID and advertised as a compact 16 or 32 bit service UUID.
  final List<String>? serviceUuids;

  /// Android only
  ///
  /// Specifies a manufacturer id
  /// Manufacturer ID assigned by Bluetooth SIG.
  final int? manufacturerId;

  /// Android only
  ///
  /// Specifies manufacturer data.
  @Uint8ListConverter()
  final Uint8List? manufacturerData;

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

  /// iOS only
  ///
  /// Set the deviceName to be broadcasted. Can be 10 bytes.
  final String? localName;

  /// Android only
  ///
  /// set to true if you want to include the power level in the advertisement
  /// Default: false
  final bool? includePowerLevel;

  /// Android > SDK 31 only
  ///
  /// A service solicitation UUID to advertise data.
  final String? serviceSolicitationUuid;

  AdvertiseData({
    // @Deprecated(
    //   'Please use serviceUuids, where you can also define a single service uuid.',
    // )
    this.serviceUuid,
    this.serviceUuids,
    this.manufacturerId,
    this.manufacturerData,
    this.serviceDataUuid,
    this.serviceData,
    this.includeDeviceName = false,
    this.localName,
    this.includePowerLevel = false,
    this.serviceSolicitationUuid,
  });

  factory AdvertiseData.fromJson(Map<String, dynamic> json) =>
      _$AdvertiseDataFromJson(json);

  Map<String, dynamic> toJson() => _$AdvertiseDataToJson(this);
}
