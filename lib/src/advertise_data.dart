/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

/// Model of the data to be advertised.
class AdvertiseData {
  /// Android & iOS
  ///
  /// Specifies the UUID to be advertised
  String? uuid;

  /// Android only
  ///
  /// Specifies a manufacturer id
  int? manufacturerId;

  /// Android only
  ///
  /// Specifies manufacturer data.
  List<int>? manufacturerData;

  /// Android only
  ///
  /// Specifies service data UUID
  String? serviceDataUuid;

  /// Android only
  ///
  /// Specifies service data
  List<int>? serviceData;

  /// Android only
  ///
  /// Set to true if device name needs to be included with advertisement
  bool? includeDeviceName;

  /// iOS only
  ///
  /// Set the deviceName to be broadcasted. Can be 10 bytes.
  List<int>? deviceName;

  /// Android only
  ///
  /// set to true if you want to include the power level in the advertisement
  bool? transmissionPowerIncluded;

  /// Android only
  ///
  /// Set advertise mode to control the advertising power and latency.
  AdvertiseMode advertiseMode = AdvertiseMode.ADVERTISE_MODE_LOW_LATENCY;

  /// Android only
  ///
  /// Set whether the advertisement type should be connectable or non-connectable.
  bool? connectable;

  /// Android only
  ///
  /// Limit advertising to a given amount of time.
  /// May not exceed 180000 milliseconds.
  int? timeout;

  /// Android only
  ///
  /// Set advertise TX power level to control the transmission power level for the advertising.
  AdvertisePower txPowerLevel = AdvertisePower.ADVERTISE_TX_POWER_HIGH;
}

enum AdvertiseMode {
  /// Perform Bluetooth LE advertising in low power mode. This is the default and preferred
  /// advertising mode as it consumes the least power.
  ADVERTISE_MODE_LOW_POWER,

  /// Perform Bluetooth LE advertising in balanced power mode. This is balanced between advertising
  /// frequency and power consumption.
  ADVERTISE_MODE_BALANCED,

  /// Perform Bluetooth LE advertising in low latency, high power mode. This has the highest power
  /// consumption and should not be used for continuous background advertising.
  ADVERTISE_MODE_LOW_LATENCY
}

enum AdvertisePower {
  /// Advertise using the lowest transmission (TX) power level. Low transmission power can be used
  /// to restrict the visibility range of advertising packets.
  ADVERTISE_TX_POWER_ULTRA_LOW,

  /// Advertise using low TX power level.
  ADVERTISE_TX_POWER_LOW,

  /// Advertise using medium TX power level.
  ADVERTISE_TX_POWER_MEDIUM,

  /// Advertise using high TX power level. This corresponds to largest visibility range of the
  /// advertising packet.
  ADVERTISE_TX_POWER_HIGH
}
