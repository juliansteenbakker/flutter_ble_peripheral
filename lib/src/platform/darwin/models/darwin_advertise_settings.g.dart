// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'darwin_advertise_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DarwinAdvertiseSettings _$DarwinAdvertiseSettingsFromJson(
        Map<String, dynamic> json) =>
    DarwinAdvertiseSettings(
      overflowServiceUuids: (json['overflowServiceUuids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      solicitedServiceUuids: (json['solicitedServiceUuids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$DarwinAdvertiseSettingsToJson(
        DarwinAdvertiseSettings instance) =>
    <String, dynamic>{
      'overflowServiceUuids': instance.overflowServiceUuids,
      'solicitedServiceUuids': instance.solicitedServiceUuids,
    };
