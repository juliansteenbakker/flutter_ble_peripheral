import 'package:json_annotation/json_annotation.dart';

part 'periodic_advertise_settings.g.dart';

/// Model of the data to be advertised.
@JsonSerializable()
class PeriodicAdvertiseSettings {
  final int? interval;

  final bool? includeTxPowerLevel;

  PeriodicAdvertiseSettings({
    this.interval = 100,
    this.includeTxPowerLevel = false,
  });

  factory PeriodicAdvertiseSettings.fromJson(Map<String, dynamic> json) =>
      _$PeriodicAdvertiseSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$PeriodicAdvertiseSettingsToJson(this);
}
