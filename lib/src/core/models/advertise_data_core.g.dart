// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'advertise_data_core.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdvertiseDataCore _$AdvertiseDataCoreFromJson(Map<String, dynamic> json) =>
    AdvertiseDataCore(
      serviceUuid: json['serviceUuid'] as String?,
      serviceUuids: (json['serviceUuids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      localName: json['localName'] as String?,
      manufacturerId: (json['manufacturerId'] as num?)?.toInt(),
      manufacturerData: const Uint8ListConverter()
          .fromJson(json['manufacturerData'] as List?),
      includeTxPowerLevel: json['includeTxPowerLevel'] as bool? ?? false,
    );

Map<String, dynamic> _$AdvertiseDataCoreToJson(AdvertiseDataCore instance) =>
    <String, dynamic>{
      'serviceUuid': instance.serviceUuid,
      'serviceUuids': instance.serviceUuids,
      'localName': instance.localName,
      'manufacturerId': instance.manufacturerId,
      'manufacturerData':
          const Uint8ListConverter().toJson(instance.manufacturerData),
      'includeTxPowerLevel': instance.includeTxPowerLevel,
    };
