import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

/// Model of the data to be advertised.
class AdvertiseSetParameters {
  final int? anonymous;

  /// Android only
  ///
  /// Set whether the advertisement type should be connectable or non-connectable.
  /// Default: false
  final bool connectable;

  final bool? includeTxPowerLevel;

  final int? interval;

  final bool? legacyMode;

  final int? primaryPhy;

  final bool? scannable;

  final int? secondaryPhy;

  /// Android only
  ///
  /// Set advertise TX power level to control the transmission power level for the advertising.
  /// Default: AdvertisePower.ADVERTISE_TX_POWER_HIGH
  final int txPowerLevel;

  final int? duration;

  final int? maxExtendedAdvertisingEvents;

  AdvertiseSetParameters({
    this.connectable = false,
    this.txPowerLevel = txPowerHigh,
    this.interval = intervalHigh,
    this.legacyMode = false,
    this.primaryPhy,
    this.scannable,
    this.secondaryPhy,
    this.anonymous,
    this.includeTxPowerLevel = false,
    this.duration,
    this.maxExtendedAdvertisingEvents,
  });
}
