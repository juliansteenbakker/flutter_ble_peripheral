import 'package:json_annotation/json_annotation.dart';

part 'periodic_advertise_settings.g.dart';

/// Settings for the periodic advertisement of an advertising set.
///
/// Only used on Android 8 and up, alongside `AdvertiseSetParameters`.
@JsonSerializable()
class PeriodicAdvertiseSettings {
  /// Creates the settings for a periodic advertisement.
  PeriodicAdvertiseSettings({
    this.interval = 100,
    this.includeTxPowerLevel = false,
  });

  /// Creates settings from the map [toJson] produces.
  factory PeriodicAdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$PeriodicAdvertiseSettingsFromJson(json);

  /// How often to send the periodic advertisement, in units of 1.25 ms.
  final int? interval;

  /// Whether the TX power level should be included in the periodic
  /// advertisement.
  final bool? includeTxPowerLevel;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$PeriodicAdvertiseSettingsToJson(this);
}
