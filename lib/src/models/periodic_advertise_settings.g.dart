// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'periodic_advertise_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeriodicAdvertiseSettings _$PeriodicAdvertiseSettingsFromJson(
        Map<String, dynamic> json) =>
    PeriodicAdvertiseSettings(
      interval: json['interval'] as int? ?? 100,
      includeTxPowerLevel: json['includeTxPowerLevel'] as bool? ?? false,
    );

Map<String, dynamic> _$PeriodicAdvertiseSettingsToJson(
        PeriodicAdvertiseSettings instance) =>
    <String, dynamic>{
      'interval': instance.interval,
      'includeTxPowerLevel': instance.includeTxPowerLevel,
    };
