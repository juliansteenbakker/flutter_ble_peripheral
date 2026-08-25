import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advertise_set_parameters.g.dart';

/// Parameters for an advertising set, used on Android 8 and up.
///
/// These map onto Android's `AdvertisingSetParameters`, which is what the
/// plugin advertises with when [AdvertiseSettings.advertiseSet] is set.
@JsonSerializable()
class AdvertiseSetParameters {
  /// Creates the parameters for an advertising set.
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

  /// Creates parameters from the map [toJson] produces.
  factory AdvertiseSetParameters.fromJson(Map<String, dynamic> json) =>
      _$AdvertiseSetParametersFromJson(json);

  /// Android only
  ///
  /// Set whether the advertisement should be anonymous, omitting the device
  /// address from it. Only available when advertising in non-legacy mode.
  /// Default: false
  final bool? anonymous;

  /// Android only
  ///
  /// Set whether the advertisement type should be connectable or
  /// non-connectable.
  /// Default: false
  final bool connectable;

  /// Android only
  ///
  /// Set whether the TX power level should be included in the advertisement.
  /// Default: false
  final bool? includeTxPowerLevel;

  /// Android only
  ///
  /// How often to advertise, in units of 0.625 ms. See [intervalLow],
  /// [intervalMedium] and [intervalHigh], or pass a value between
  /// [intervalMin] and [intervalMax].
  /// Default: [intervalHigh]
  final int? interval;

  /// Android only
  ///
  /// Set whether to advertise in the legacy format, so that devices without
  /// Bluetooth 5 support can still see the advertisement. Turning this off
  /// allows a larger payload, at the cost of reaching fewer devices.
  /// Default: false
  final bool? legacyMode;

  /// Android only
  ///
  /// The PHY to advertise the primary advertisement on. Accepts the values of
  /// Android's `BluetoothDevice.PHY_LE_*` constants.
  final int? primaryPhy;

  /// Android only
  ///
  /// Set whether the advertisement should be scannable, meaning a central may
  /// ask for the scan response data.
  final bool? scannable;

  /// Android only
  ///
  /// The PHY to advertise the secondary advertisement on. Accepts the values of
  /// Android's `BluetoothDevice.PHY_LE_*` constants, and is ignored in
  /// [legacyMode].
  final int? secondaryPhy;

  /// Android only
  ///
  /// Set advertise TX power level to control the transmission power level for
  /// the advertising. See [txPowerLow], [txPowerMedium] and [txPowerHigh], or
  /// pass a value in dBm between [txPowerMin] and [txPowerMax].
  /// Default: [txPowerHigh]
  final int txPowerLevel;

  /// Android only
  ///
  /// How long to advertise for, in units of 10 ms. Advertises until stopped
  /// when left unset.
  final int? duration;

  /// Android only
  ///
  /// How many extended advertising events to send before stopping. Sends them
  /// until stopped when left unset.
  final int? maxExtendedAdvertisingEvents;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$AdvertiseSetParametersToJson(this);
}
