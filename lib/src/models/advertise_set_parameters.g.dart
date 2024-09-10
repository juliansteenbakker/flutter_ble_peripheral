// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advertise_set_parameters.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdvertiseSetParameters _$AdvertiseSetParametersFromJson(
        Map<String, dynamic> json) =>
    AdvertiseSetParameters(
      connectable: json['connectable'] as bool? ?? false,
      txPowerLevel: (json['txPowerLevel'] as num?)?.toInt() ?? txPowerHigh,
      interval: (json['interval'] as num?)?.toInt() ?? intervalHigh,
      legacyMode: json['legacyMode'] as bool? ?? false,
      primaryPhy: (json['primaryPhy'] as num?)?.toInt(),
      scannable: json['scannable'] as bool?,
      secondaryPhy: (json['secondaryPhy'] as num?)?.toInt(),
      anonymous: (json['anonymous'] as num?)?.toInt(),
      includeTxPowerLevel: json['includeTxPowerLevel'] as bool? ?? false,
      duration: (json['duration'] as num?)?.toInt(),
      maxExtendedAdvertisingEvents:
          (json['maxExtendedAdvertisingEvents'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AdvertiseSetParametersToJson(
        AdvertiseSetParameters instance) =>
    <String, dynamic>{
      'anonymous': instance.anonymous,
      'connectable': instance.connectable,
      'includeTxPowerLevel': instance.includeTxPowerLevel,
      'interval': instance.interval,
      'legacyMode': instance.legacyMode,
      'primaryPhy': instance.primaryPhy,
      'scannable': instance.scannable,
      'secondaryPhy': instance.secondaryPhy,
      'txPowerLevel': instance.txPowerLevel,
      'duration': instance.duration,
      'maxExtendedAdvertisingEvents': instance.maxExtendedAdvertisingEvents,
    };
