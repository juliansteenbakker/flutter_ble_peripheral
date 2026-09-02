import 'package:json_annotation/json_annotation.dart';

part 'periodic_advertise_settings.g.dart';

/// Periodic advertising settings for Android extended advertising.
///
/// Maps to `PeriodicAdvertisingParameters.Builder` in Android native code. Used
/// with `AndroidAdvertiseSettings.periodicAdvertiseSettings`.
///
/// Requires Android 8.0 (API level 26) or higher.
@JsonSerializable()
class PeriodicAdvertiseSettings {
  /// Creates the settings for a periodic advertisement.
  const PeriodicAdvertiseSettings({
    this.interval = 100,
    this.includeTxPowerLevel = false,
  });

  /// Creates settings from the map [toJson] produces.
  factory PeriodicAdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$PeriodicAdvertiseSettingsFromJson(json);

  /// Advertising interval for periodic advertising, in units of 1.25ms.
  ///
  /// Valid range: 80 to 65535 (100ms to 81.91875s). Default: 100 (125ms)
  ///
  /// Android API: `PeriodicAdvertisingParameters.Builder.setInterval(interval)`
  final int? interval;

  /// Whether the transmission power level should be included in the periodic
  /// advertisement.
  ///
  /// Default: false
  ///
  /// Android API:
  /// `PeriodicAdvertisingParameters.Builder.setIncludeTxPower(...)`
  final bool? includeTxPowerLevel;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$PeriodicAdvertiseSettingsToJson(this);
}
