// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'gatt_server_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GattServerSettings _$GattServerSettingsFromJson(Map<String, dynamic> json) =>
    GattServerSettings(
      serviceUuid: json['serviceUuid'] as String?,
      txCharacteristicUuid: json['txCharacteristicUuid'] as String? ??
          defaultTxCharacteristicUuid,
      rxCharacteristicUuid: json['rxCharacteristicUuid'] as String? ??
          defaultRxCharacteristicUuid,
    );

Map<String, dynamic> _$GattServerSettingsToJson(GattServerSettings instance) =>
    <String, dynamic>{
      'serviceUuid': instance.serviceUuid,
      'txCharacteristicUuid': instance.txCharacteristicUuid,
      'rxCharacteristicUuid': instance.rxCharacteristicUuid,
    };
