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
  /// Specifies the service UUID to be advertised
  final String? serviceUuid;

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
    this.serviceUuid,
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
