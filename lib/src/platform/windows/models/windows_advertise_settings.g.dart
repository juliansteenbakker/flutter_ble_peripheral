// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'windows_advertise_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WindowsAdvertiseSettings _$WindowsAdvertiseSettingsFromJson(
        Map<String, dynamic> json) =>
    WindowsAdvertiseSettings(
      timeout: (json['timeout'] as num?)?.toInt() ?? 0,
      flags: (json['flags'] as num?)?.toInt(),
      useExtendedAdvertisement:
          json['useExtendedAdvertisement'] as bool? ?? false,
      preferredTransmitPowerLevel:
          (json['preferredTransmitPowerLevel'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WindowsAdvertiseSettingsToJson(
        WindowsAdvertiseSettings instance) =>
    <String, dynamic>{
      'timeout': instance.timeout,
      'flags': instance.flags,
      'useExtendedAdvertisement': instance.useExtendedAdvertisement,
      'preferredTransmitPowerLevel': instance.preferredTransmitPowerLevel,
    };
