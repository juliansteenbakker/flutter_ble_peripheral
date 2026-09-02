import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidAdvertiseData', () {
    test('round trips', () {
      final data = AndroidAdvertiseData(
        serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
        manufacturerId: 1234,
        manufacturerData: Uint8List.fromList([1, 2, 3]),
        serviceDataUuid: '0000feaa-0000-1000-8000-00805f9b34fb',
        serviceData: const [16, 32],
        includeDeviceName: true,
        localName: 'Peripheral',
        includeTxPowerLevel: true,
        serviceSolicitationUuid: '0000180d-0000-1000-8000-00805f9b34fb',
      );

      final decoded = AndroidAdvertiseData.fromJson(data.toJson());

      expect(decoded.serviceUuid, data.serviceUuid);
      expect(decoded.manufacturerId, 1234);
      expect(decoded.manufacturerData, data.manufacturerData);
      expect(decoded.serviceDataUuid, data.serviceDataUuid);
      expect(decoded.serviceData, const [16, 32]);
      expect(decoded.includeDeviceName, true);
      expect(decoded.localName, 'Peripheral');
      expect(decoded.includeTxPowerLevel, true);
      expect(decoded.serviceSolicitationUuid, data.serviceSolicitationUuid);
    });

    test('applies its defaults', () {
      const data = AndroidAdvertiseData();

      expect(data.includeDeviceName, false);
      expect(data.includeTxPowerLevel, false);
      expect(data.serviceUuid, isNull);
      expect(data.serviceUuids, isNull);
    });

    test('encodes the manufacturer data as a plain int list', () {
      final json = AndroidAdvertiseData(
        manufacturerData: Uint8List.fromList([1, 2, 3]),
      ).toJson();

      expect(json['manufacturerData'], const [1, 2, 3]);
    });

    test('encodes serviceUuids', () {
      const json = ['abcd'];
      expect(
        const AndroidAdvertiseData(serviceUuids: json).toJson()['serviceUuids'],
        json,
      );
    });

    test('carries the core fields over from AdvertiseDataCore', () {
      const core = AdvertiseDataCore(
        serviceUuid: 'abcd',
        serviceUuids: ['abcd', 'ef01'],
        localName: 'Peripheral',
      );

      final data = AndroidAdvertiseData.fromCore(core);

      expect(data.serviceUuid, core.serviceUuid);
      expect(data.serviceUuids, core.serviceUuids);
      expect(data.localName, core.localName);
    });
  });

  group('AdvertiseSettings', () {
    // These numbers are the wire format shared with the Android side, so they
    // must not drift.
    test('encodes enums as their Android constants', () {
      final json = const AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
      ).toJson();

      expect(json['advertiseMode'], 1);
      expect(json['txPowerLevel'], 3);
    });

    test('applies its defaults', () {
      final json = const AdvertiseSettings().toJson();

      expect(json['connectable'], false);
      expect(json['timeout'], 0);
      expect(json['advertiseMode'], 2);
      expect(json['txPowerLevel'], 3);
    });

    test('round trips', () {
      const settings = AdvertiseSettings(
        connectable: true,
        timeout: 1000,
        advertiseMode: AdvertiseMode.advertiseModeLowPower,
      );

      final decoded = AdvertiseSettings.fromJson(settings.toJson());

      expect(decoded.connectable, true);
      expect(decoded.timeout, 1000);
      expect(decoded.advertiseMode, AdvertiseMode.advertiseModeLowPower);
      expect(decoded.txPowerLevel, AdvertiseTxPower.advertiseTxPowerHigh);
    });
  });

  group('AdvertiseSetParameters', () {
    test('applies its defaults', () {
      final json = const AdvertiseSetParameters().toJson();

      expect(json['connectable'], false);
      expect(json['txPowerLevel'], txPowerHigh);
      expect(json['interval'], intervalHigh);
      expect(json['legacyMode'], false);
      expect(json['includeTxPowerLevel'], false);
    });

    test('round trips', () {
      const parameters = AdvertiseSetParameters(
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
        const AdvertiseSetParameters(anonymous: true).toJson()['anonymous'],
        true,
      );
      expect(const AdvertiseSetParameters().toJson()['anonymous'], isNull);
      expect(
        AdvertiseSetParameters.fromJson(
          const AdvertiseSetParameters(anonymous: true).toJson(),
        ).anonymous,
        true,
      );
    });
  });

  group('PeriodicAdvertiseSettings', () {
    test('round trips and applies its defaults', () {
      final json = const PeriodicAdvertiseSettings().toJson();

      expect(json['interval'], 100);
      expect(json['includeTxPowerLevel'], false);

      final decoded = PeriodicAdvertiseSettings.fromJson(
        const PeriodicAdvertiseSettings(interval: 250).toJson(),
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

  group('PeripheralBluetoothState', () {
    // start/stop index into values with the raw int from the channel, so the
    // declared order has to stay in step with the native enums.
    test('index matches the native state code', () {
      expect(
        PeripheralBluetoothState.values[0],
        PeripheralBluetoothState.granted,
      );
      expect(
        PeripheralBluetoothState.values[5],
        PeripheralBluetoothState.turnedOff,
      );
      expect(
        PeripheralBluetoothState.values[8],
        PeripheralBluetoothState.ready,
      );
      expect(PeripheralBluetoothState.values, hasLength(9));
    });

    test('the BluetoothPeripheralState alias resolves to it', () {
      // Exercising the deprecated alias is the point of this test.
      // ignore: deprecated_member_use_from_same_package
      const state = BluetoothPeripheralState.ready;
      expect(state, PeripheralBluetoothState.ready);
    });
  });

  group('PeripheralState', () {
    // onPeripheralStateChanged indexes into values with the raw channel int.
    test('index matches the native state code', () {
      expect(
        PeripheralState.values[0],
        PeripheralState.unknown,
      );
      expect(
        PeripheralState.values[5],
        PeripheralState.idle,
      );
      expect(
        PeripheralState.values[6],
        PeripheralState.advertising,
      );
      expect(
        PeripheralState.values[7],
        PeripheralState.connected,
      );
    });
  });
}
