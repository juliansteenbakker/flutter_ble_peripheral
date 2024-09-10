// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advertise_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdvertiseData _$AdvertiseDataFromJson(Map<String, dynamic> json) =>
    AdvertiseData(
      serviceUuid: json['serviceUuid'] as String?,
      manufacturerId: (json['manufacturerId'] as num?)?.toInt(),
      manufacturerData: const Uint8ListConverter()
          .fromJson(json['manufacturerData'] as List?),
      serviceDataUuid: json['serviceDataUuid'] as String?,
      serviceData: (json['serviceData'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      includeDeviceName: json['includeDeviceName'] as bool? ?? false,
      localName: json['localName'] as String?,
      includePowerLevel: json['includePowerLevel'] as bool? ?? false,
      serviceSolicitationUuid: json['serviceSolicitationUuid'] as String?,
    );

Map<String, dynamic> _$AdvertiseDataToJson(AdvertiseData instance) =>
    <String, dynamic>{
      'serviceUuid': instance.serviceUuid,
      'manufacturerId': instance.manufacturerId,
      'manufacturerData':
          const Uint8ListConverter().toJson(instance.manufacturerData),
      'serviceDataUuid': instance.serviceDataUuid,
      'serviceData': instance.serviceData,
      'includeDeviceName': instance.includeDeviceName,
      'localName': instance.localName,
      'includePowerLevel': instance.includePowerLevel,
      'serviceSolicitationUuid': instance.serviceSolicitationUuid,
    };
