import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdvertiseData', () {
    test('round trips', () {
      final data = AdvertiseData(
        serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
        manufacturerId: 1234,
        manufacturerData: Uint8List.fromList([1, 2, 3]),
        serviceDataUuid: '0000feaa-0000-1000-8000-00805f9b34fb',
        serviceData: const [16, 32],
        includeDeviceName: true,
        localName: 'Peripheral',
        includePowerLevel: true,
        serviceSolicitationUuid: '0000180d-0000-1000-8000-00805f9b34fb',
      );

      final decoded = AdvertiseData.fromJson(data.toJson());

      expect(decoded.serviceUuid, data.serviceUuid);
      expect(decoded.manufacturerId, 1234);
      expect(decoded.manufacturerData, data.manufacturerData);
      expect(decoded.serviceDataUuid, data.serviceDataUuid);
      expect(decoded.serviceData, const [16, 32]);
      expect(decoded.includeDeviceName, true);
      expect(decoded.localName, 'Peripheral');
      expect(decoded.includePowerLevel, true);
      expect(decoded.serviceSolicitationUuid, data.serviceSolicitationUuid);
    });

    test('applies its defaults', () {
      final data = AdvertiseData();

      expect(data.includeDeviceName, false);
      expect(data.includePowerLevel, false);
      expect(data.serviceUuid, isNull);
      expect(data.serviceUuids, isNull);
    });

    test('encodes the manufacturer data as a plain int list', () {
      final json = AdvertiseData(
        manufacturerData: Uint8List.fromList([1, 2, 3]),
      ).toJson();

      expect(json['manufacturerData'], const [1, 2, 3]);
    });

    test('encodes serviceUuids', () {
      final json = AdvertiseData(serviceUuids: const ['abcd']).toJson();

      expect(json['serviceUuids'], const ['abcd']);
    });
  });

  group('AdvertiseSettings', () {
    // These numbers are the wire format shared with the Android side, so they
    // must not drift.
    test('encodes enums as their Android constants', () {
      final json = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
      ).toJson();

      expect(json['advertiseMode'], 1);
      expect(json['txPowerLevel'], 3);
    });

    test('applies its defaults', () {
      final json = AdvertiseSettings().toJson();

      expect(json['advertiseSet'], true);
      expect(json['connectable'], false);
      expect(json['timeout'], 400);
      expect(json['advertiseMode'], 2);
      expect(json['txPowerLevel'], 1);
    });

    test('round trips', () {
      final settings = AdvertiseSettings(
        connectable: true,
        timeout: 1000,
        advertiseMode: AdvertiseMode.advertiseModeLowPower,
      );

      final decoded = AdvertiseSettings.fromJson(settings.toJson());

      expect(decoded.connectable, true);
      expect(decoded.timeout, 1000);
      expect(decoded.advertiseMode, AdvertiseMode.advertiseModeLowPower);
      expect(decoded.txPowerLevel, AdvertiseTxPower.advertiseTxPowerLow);
    });
  });

  group('AdvertiseSetParameters', () {
    test('applies its defaults', () {
      final json = AdvertiseSetParameters().toJson();

      expect(json['connectable'], false);
      expect(json['txPowerLevel'], txPowerHigh);
      expect(json['interval'], intervalHigh);
      expect(json['legacyMode'], false);
      expect(json['includeTxPowerLevel'], false);
    });

    test('round trips', () {
      final parameters = AdvertiseSetParameters(
        connectable: true,
        interval: intervalMedium,
        primaryPhy: 1,
        secondaryPhy: 2,
        scannable: true,
        duration: 100,
        maxExtendedAdvertisingEvents: 5,
      );

      final decoded = AdvertiseSetParameters.fromJson(parameters.toJson());

      expect(decoded.connectable, true);
      expect(decoded.interval, intervalMedium);
      expect(decoded.primaryPhy, 1);
      expect(decoded.secondaryPhy, 2);
      expect(decoded.scannable, true);
      expect(decoded.duration, 100);
      expect(decoded.maxExtendedAdvertisingEvents, 5);
    });

    // Android reads setanonymous as a Boolean, so this has to go over the
    // channel as a bool rather than an int.
    test('encodes anonymous as a bool', () {
      expect(
        AdvertiseSetParameters(anonymous: true).toJson()['anonymous'],
        true,
      );
      expect(AdvertiseSetParameters().toJson()['anonymous'], isNull);
      expect(
        AdvertiseSetParameters.fromJson(
          AdvertiseSetParameters(anonymous: true).toJson(),
        ).anonymous,
        true,
      );
    });
  });

  group('PeriodicAdvertiseSettings', () {
    test('round trips and applies its defaults', () {
      final json = PeriodicAdvertiseSettings().toJson();

      expect(json['interval'], 100);
      expect(json['includeTxPowerLevel'], false);

      final decoded = PeriodicAdvertiseSettings.fromJson(
        PeriodicAdvertiseSettings(interval: 250).toJson(),
      );
      expect(decoded.interval, 250);
    });
  });

  group('Android constants', () {
    test('match the platform values', () {
      expect(intervalMin, 160);
      expect(intervalLow, 160);
      expect(intervalMedium, 400);
      expect(intervalHigh, 1600);
      expect(intervalMax, 16777215);

      expect(txPowerMin, -127);
      expect(txPowerUltraLow, -21);
      expect(txPowerLow, -15);
      expect(txPowerMedium, -7);
      expect(txPowerHigh, 1);
      expect(txPowerMax, 1);
    });
  });

  group('BluetoothPeripheralState', () {
    // start/stop index into values with the raw int from the channel, so the
    // declared order has to stay in step with the native enums.
    test('index matches the native state code', () {
      expect(
        BluetoothPeripheralState.values[0],
        BluetoothPeripheralState.granted,
      );
      expect(
        BluetoothPeripheralState.values[5],
        BluetoothPeripheralState.turnedOff,
      );
      expect(
        BluetoothPeripheralState.values[8],
        BluetoothPeripheralState.ready,
      );
      expect(BluetoothPeripheralState.values, hasLength(9));
    });
  });

  group('PeripheralState', () {
    // onPeripheralStateChanged indexes into values with the raw channel int.
    test('index matches the native state code', () {
      expect(PeripheralState.values[0], PeripheralState.unknown);
      expect(PeripheralState.values[5], PeripheralState.advertising);
      expect(PeripheralState.values[6], PeripheralState.connected);
    });
  });
}
