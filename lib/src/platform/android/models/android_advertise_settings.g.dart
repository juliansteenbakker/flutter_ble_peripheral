// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'android_advertise_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AndroidAdvertiseSettings _$AndroidAdvertiseSettingsFromJson(
        Map<String, dynamic> json) =>
    AndroidAdvertiseSettings(
      advertiseSettings: json['advertiseSettings'] == null
          ? null
          : AdvertiseSettings.fromJson(
              json['advertiseSettings'] as Map<String, dynamic>),
      advertiseSetParameters: json['advertiseSetParameters'] == null
          ? null
          : AdvertiseSetParameters.fromJson(
              json['advertiseSetParameters'] as Map<String, dynamic>),
      advertiseResponseData: json['advertiseResponseData'] == null
          ? null
          : AndroidAdvertiseData.fromJson(
              json['advertiseResponseData'] as Map<String, dynamic>),
      periodicAdvertiseData: json['periodicAdvertiseData'] == null
          ? null
          : AndroidAdvertiseData.fromJson(
              json['periodicAdvertiseData'] as Map<String, dynamic>),
      periodicAdvertiseSettings: json['periodicAdvertiseSettings'] == null
          ? null
          : PeriodicAdvertiseSettings.fromJson(
              json['periodicAdvertiseSettings'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AndroidAdvertiseSettingsToJson(
        AndroidAdvertiseSettings instance) =>
    <String, dynamic>{
      'advertiseSettings': instance.advertiseSettings,
      'advertiseSetParameters': instance.advertiseSetParameters,
      'advertiseResponseData': instance.advertiseResponseData,
      'periodicAdvertiseData': instance.periodicAdvertiseData,
      'periodicAdvertiseSettings': instance.periodicAdvertiseSettings,
    };
