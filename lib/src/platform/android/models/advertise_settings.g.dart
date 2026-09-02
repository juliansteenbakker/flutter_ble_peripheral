// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'advertise_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdvertiseSettings _$AdvertiseSettingsFromJson(Map<String, dynamic> json) =>
    AdvertiseSettings(
      connectable: json['connectable'] as bool? ?? false,
      timeout: (json['timeout'] as num?)?.toInt() ?? 0,
      advertiseMode:
          $enumDecodeNullable(_$AdvertiseModeEnumMap, json['advertiseMode']) ??
              AdvertiseMode.advertiseModeLowLatency,
      txPowerLevel: $enumDecodeNullable(
              _$AdvertiseTxPowerEnumMap, json['txPowerLevel']) ??
          AdvertiseTxPower.advertiseTxPowerHigh,
    );

Map<String, dynamic> _$AdvertiseSettingsToJson(AdvertiseSettings instance) =>
    <String, dynamic>{
      'advertiseMode': _$AdvertiseModeEnumMap[instance.advertiseMode]!,
      'connectable': instance.connectable,
      'timeout': instance.timeout,
      'txPowerLevel': _$AdvertiseTxPowerEnumMap[instance.txPowerLevel]!,
    };

const _$AdvertiseModeEnumMap = {
  AdvertiseMode.advertiseModeLowPower: 0,
  AdvertiseMode.advertiseModeBalanced: 1,
  AdvertiseMode.advertiseModeLowLatency: 2,
};

const _$AdvertiseTxPowerEnumMap = {
  AdvertiseTxPower.advertiseTxPowerUltraLow: 0,
  AdvertiseTxPower.advertiseTxPowerLow: 1,
  AdvertiseTxPower.advertiseTxPowerMedium: 2,
  AdvertiseTxPower.advertiseTxPowerHigh: 3,
};
