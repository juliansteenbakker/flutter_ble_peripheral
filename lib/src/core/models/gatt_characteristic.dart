/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter_ble_peripheral/src/core/enums/gatt_characteristic_property.dart';

/// One characteristic of the service the peripheral serves.
///
/// The 16 bit (`'2a37'`), 32 bit and 128 bit uuid forms are all accepted, and
/// a short one is expanded onto the Bluetooth Base UUID by the platform.
class GattCharacteristic {
  /// Creates a characteristic with the given [properties].
  const GattCharacteristic({
    required this.uuid,
    required this.properties,
  });

  /// A characteristic the peripheral notifies on, and a central may read.
  ///
  /// This is what `FlutterBlePeripheral.sendData` delivers over, and it is the
  /// shape of the default TX characteristic.
  const GattCharacteristic.notify(this.uuid)
      : properties = const {
          GattCharacteristicProperty.read,
          GattCharacteristicProperty.notify,
          GattCharacteristicProperty.indicate,
        };

  /// A characteristic a central writes to, with or without a response.
  ///
  /// What arrives on it is reported by `FlutterBlePeripheral.onGattWrite`, and
  /// it is the shape of the default RX characteristic.
  const GattCharacteristic.write(this.uuid)
      : properties = const {
          GattCharacteristicProperty.write,
          GattCharacteristicProperty.writeWithoutResponse,
        };

  /// Creates a characteristic from the map [toJson] produces.
  factory GattCharacteristic.fromJson(Map<String, dynamic> json) {
    final bits = json['properties'] as int? ?? 0;
    return GattCharacteristic(
      uuid: json['uuid'] as String,
      properties: GattCharacteristicProperty.values
          .where((property) => bits & property.bit != 0)
          .toSet(),
    );
  }

  /// The uuid of the characteristic.
  final String uuid;

  /// What a central may do with it.
  final Set<GattCharacteristicProperty> properties;

  /// Whether the peripheral can push a value to a subscribed central, which is
  /// what [GattCharacteristicProperty.notify] and
  /// [GattCharacteristicProperty.indicate] allow.
  bool get canNotify =>
      properties.contains(GattCharacteristicProperty.notify) ||
      properties.contains(GattCharacteristicProperty.indicate);

  /// Whether a central may write to it.
  bool get canWrite =>
      properties.contains(GattCharacteristicProperty.write) ||
      properties.contains(GattCharacteristicProperty.writeWithoutResponse);

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'uuid': uuid,
        'properties': properties.fold<int>(
          0,
          (bits, property) => bits | property.bit,
        ),
      };

  /// Creates a copy with optional field replacements.
  GattCharacteristic copyWith({
    String? uuid,
    Set<GattCharacteristicProperty>? properties,
  }) {
    return GattCharacteristic(
      uuid: uuid ?? this.uuid,
      properties: properties ?? this.properties,
    );
  }
}
