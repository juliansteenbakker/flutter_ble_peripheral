
import 'package:flutter_ble_peripheral/src/models/enums/advertise_mode.dart';
import 'package:flutter_ble_peripheral/src/models/enums/advertise_tx_power.dart';

/// Model of the data to be advertised.
class AdvertiseSettings {

  /// Android only
  ///
  /// Set advertise mode to control the advertising power and latency.
  /// Default: AdvertiseMode.ADVERTISE_MODE_LOW_LATENCY
  final AdvertiseMode advertiseMode;

  /// Android only
  ///
  /// Set whether the advertisement type should be connectable or non-connectable.
  /// Default: false
  final bool connectable;

  /// Android only
  ///
  /// Limit advertising to a given amount of time.
  /// May not exceed 180000 milliseconds.
  /// Default: 400 milliseconds
  final int timeout;

  /// Android only
  ///
  /// Set advertise TX power level to control the transmission power level for the advertising.
  /// Default: AdvertisePower.ADVERTISE_TX_POWER_HIGH
  final AdvertiseTxPower txPowerLevel;

  AdvertiseSettings({
  this.connectable = false,
  this.timeout = 400,
  this.advertiseMode = AdvertiseMode.advertiseModeLowLatency,
  this.txPowerLevel = AdvertiseTxPower.advertiseTxPowerLow,
  });
}
