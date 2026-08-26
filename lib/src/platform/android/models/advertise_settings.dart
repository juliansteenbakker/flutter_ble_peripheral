import 'package:flutter_ble_peripheral/src/platform/android/enums/advertise_mode.dart';
import 'package:flutter_ble_peripheral/src/platform/android/models/advertise_tx_power.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advertise_settings.g.dart';

/// Legacy advertising settings for Android (pre-Android 8).
///
/// Maps to `AdvertiseSettings.Builder` in Android native code.
///
/// For Android 8+ (API level 26), consider using `AdvertiseSetParameters`
/// instead for access to extended advertising features.
///
/// Reference:
/// https://developer.android.com/reference/android/bluetooth/le/AdvertiseSettings
@JsonSerializable()
class AdvertiseSettings {
  /// Creates the legacy advertising settings.
  const AdvertiseSettings({
    this.connectable = false,
    this.timeout = 0,
    this.advertiseMode = AdvertiseMode.advertiseModeLowLatency,
    this.txPowerLevel = AdvertiseTxPower.advertiseTxPowerHigh,
  });

  /// Creates settings from the map [toJson] produces.
  factory AdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$AdvertiseSettingsFromJson(json);

  /// Set advertise mode to control the advertising power and latency.
  ///
  /// Default: [AdvertiseMode.advertiseModeLowLatency]
  ///
  /// Android API: `AdvertiseSettings.Builder.setAdvertiseMode(advertiseMode)`
  final AdvertiseMode advertiseMode;

  /// Set whether the advertisement type should be connectable or
  /// non-connectable.
  ///
  /// Default: false
  ///
  /// Android API: `AdvertiseSettings.Builder.setConnectable(connectable)`
  final bool connectable;

  /// Limit advertising to a given amount of time in milliseconds.
  ///
  /// Applies on the legacy path only; an advertising set is limited by
  /// `AdvertiseSetParameters.duration` instead. The Windows equivalent is
  /// `WindowsAdvertiseSettings.timeout`.
  ///
  /// Valid range: 0 to 180000 milliseconds, where 0 leaves the advertisement
  /// up. Default: 0
  ///
  /// Android API: `AdvertiseSettings.Builder.setTimeout(timeout)`
  final int timeout;

  /// Set advertise TX power level to control the transmission power level for
  /// the advertising.
  ///
  /// Default: [AdvertiseTxPower.advertiseTxPowerHigh]
  ///
  /// Android API: `AdvertiseSettings.Builder.setTxPowerLevel(txPowerLevel)`
  final AdvertiseTxPower txPowerLevel;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$AdvertiseSettingsToJson(this);
}
