// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'periodic_advertise_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeriodicAdvertiseSettings _$PeriodicAdvertiseSettingsFromJson(
        Map<String, dynamic> json) =>
    PeriodicAdvertiseSettings(
      interval: (json['interval'] as num?)?.toInt() ?? 100,
      includeTxPowerLevel: json['includeTxPowerLevel'] as bool? ?? false,
    );

Map<String, dynamic> _$PeriodicAdvertiseSettingsToJson(
        PeriodicAdvertiseSettings instance) =>
    <String, dynamic>{
      'interval': instance.interval,
      'includeTxPowerLevel': instance.includeTxPowerLevel,
    };
