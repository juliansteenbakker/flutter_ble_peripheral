/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:json_annotation/json_annotation.dart';

part 'gatt_server_settings.g.dart';

/// The Nordic UART Service, the de facto standard for a serial-style link over
/// GATT. Advertise this as the service uuid to be recognised by tools such as
/// nRF Connect.
const String nordicUartServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

/// The Nordic UART Service characteristic the peripheral notifies on, which is
/// what `FlutterBlePeripheral.sendData` writes to.
///
/// This is the default for [GattServerSettings.txCharacteristicUuid].
const String defaultTxCharacteristicUuid =
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

/// The Nordic UART Service characteristic a central writes to, which is what
/// `FlutterBlePeripheral.onDataReceived` reports.
///
/// This is the default for [GattServerSettings.rxCharacteristicUuid].
const String defaultRxCharacteristicUuid =
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

/// Asks `FlutterBlePeripheral.start` to serve a GATT service alongside the
/// advertisement.
///
/// The service holds two characteristics: a TX one the peripheral notifies on,
/// and an RX one a central writes to. Both default to the Nordic UART Service
/// characteristics, so a central that knows that profile can talk to this
/// peripheral without being told the uuids out of band. Pass your own to serve
/// a different layout.
///
/// The uuids are the contract between the two sides of the link and must be
/// stable, so they are never derived from the service uuid. The 16 bit
/// (`'180d'`), 32 bit and 128 bit forms are all accepted, and a short one is
/// expanded onto the Bluetooth Base UUID by the platform.
@JsonSerializable()
class GattServerSettings {
  /// Creates the settings for the GATT service to serve.
  const GattServerSettings({
    this.serviceUuid,
    this.txCharacteristicUuid = defaultTxCharacteristicUuid,
    this.rxCharacteristicUuid = defaultRxCharacteristicUuid,
  });

  /// Creates settings from the map [toJson] produces.
  factory GattServerSettings.fromJson(Map<String, dynamic> json) =>
      _$GattServerSettingsFromJson(json);

  /// The uuid of the service to serve.
  ///
  /// Defaults to the advertised `AdvertiseDataCore.serviceUuid`, so a
  /// central
  /// that discovers the advertisement finds the service under the same uuid.
  /// Set this to serve a service that is not the advertised one.
  final String? serviceUuid;

  /// The uuid of the characteristic the peripheral notifies on.
  ///
  /// Supports notify and indicate, and carries what
  /// `FlutterBlePeripheral.sendData` sends.
  final String txCharacteristicUuid;

  /// The uuid of the characteristic a central writes to.
  ///
  /// Supports write and write-without-response, and what arrives on it is
  /// reported by `FlutterBlePeripheral.onDataReceived`.
  final String rxCharacteristicUuid;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$GattServerSettingsToJson(this);

  /// Creates a copy with optional field replacements.
  GattServerSettings copyWith({
    String? serviceUuid,
    String? txCharacteristicUuid,
    String? rxCharacteristicUuid,
  }) {
    return GattServerSettings(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      txCharacteristicUuid: txCharacteristicUuid ?? this.txCharacteristicUuid,
      rxCharacteristicUuid: rxCharacteristicUuid ?? this.rxCharacteristicUuid,
    );
  }
}
