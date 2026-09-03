import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(
    'dev.steenbakker.flutter_ble_peripheral/ble_state',
  );

  final blePeripheral = FlutterBlePeripheral();
  final calls = <MethodCall>[];
  Object? response;

  setUp(() {
    calls.clear();
    response = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (methodCall) async {
      calls.add(methodCall);
      return response;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  Map<Object?, Object?> argumentsOf(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  test('is a singleton', () {
    expect(FlutterBlePeripheral(), same(blePeripheral));
  });

  group('start', () {
    test('sends the advertise data', () async {
      response = 8;

      final state = await blePeripheral.start(
        advertiseData: AndroidAdvertiseData(
          serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
          manufacturerId: 1234,
          manufacturerData: Uint8List.fromList([1, 2, 3]),
          localName: 'Peripheral',
        ),
      );

      expect(calls.single.method, 'start');
      final arguments = argumentsOf(calls.single);
      expect(arguments['serviceUuid'], 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7');
      expect(arguments['manufacturerId'], 1234);
      expect(arguments['localName'], 'Peripheral');
      expect(state, PeripheralBluetoothState.ready);
    });

    // Manufacturer data and the tx power flag live on AdvertiseDataCore, so
    // they go over the channel unprefixed and every platform reads the same
    // keys. Declaring them per platform was the wart the split introduced.
    test('sends the shared fields without a platform prefix', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseDataCore(
          serviceUuid: 'abcd',
          localName: 'Peripheral',
          manufacturerId: 1234,
          manufacturerData: Uint8List.fromList([1, 2, 3]),
          includeTxPowerLevel: true,
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['serviceUuid'], 'abcd');
      expect(arguments['localName'], 'Peripheral');
      expect(arguments['manufacturerId'], 1234);
      expect(arguments['manufacturerData'], const [1, 2, 3]);
      expect(arguments['includeTxPowerLevel'], true);
      expect(
        arguments.keys.where(
          (k) =>
              (k! as String).startsWith('windows') ||
              (k as String).startsWith('darwin'),
        ),
        isEmpty,
      );
    });

    // The bytes are sent twice: once encoded by the converter and once raw, so
    // that the native side can read a ByteArray directly.
    test('sends the manufacturer data raw as well', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      await blePeripheral.start(
        advertiseData: AndroidAdvertiseData(manufacturerData: bytes),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['manufacturerData'], const [1, 2, 3]);
      expect(arguments['manufacturerDataBytes'], bytes);
    });

    // serviceUuids has to reach the channel even when serviceUuid is null, so
    // that Android can advertise the list on its own.
    test('sends serviceUuids without a singular serviceUuid', () async {
      await blePeripheral.start(
        advertiseData: const AdvertiseDataCore(
          serviceUuids: ['5b0e0100-0100-1000-8000-00805f9b34fb', 'A1B2'],
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['serviceUuids'], const [
        '5b0e0100-0100-1000-8000-00805f9b34fb',
        'A1B2',
      ]);
      expect(arguments['serviceUuid'], isNull);
    });

    // The native side reads these under a response prefix and builds a separate
    // AdvertiseData for the scan response.
    test(
      'prefixes the response data with response',
      () async {
        await blePeripheral.start(
          advertiseData: const AdvertiseDataCore(serviceUuid: 'abcd'),
          androidSettings: AndroidAdvertiseSettings(
            advertiseResponseData: AndroidAdvertiseData(
              serviceUuid: 'ef01',
              manufacturerId: 1234,
              manufacturerData: Uint8List.fromList([1, 2, 3]),
              serviceDataUuid: 'FEAA',
              serviceData: const [4, 5],
              includeDeviceName: true,
            ),
          ),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['responseserviceUuid'], 'ef01');
        expect(arguments['responsemanufacturerId'], 1234);
        expect(arguments['responsemanufacturerData'], const [1, 2, 3]);
        expect(arguments['responseserviceDataUuid'], 'FEAA');
        expect(arguments['responseserviceData'], const [4, 5]);
        expect(arguments['responseincludeDeviceName'], true);
        // The primary data must not be overwritten by the response data.
        expect(arguments['serviceUuid'], 'abcd');
        expect(arguments['manufacturerData'], isNull);
      },
      skip: !Platform.isAndroid,
    );

    // The Android settings are only merged into the payload when running on
    // Android, so these two only run there.
    test(
      'honours explicit advertise settings',
      () async {
        await blePeripheral.start(
          advertiseData: const AdvertiseDataCore(),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseSettings: AdvertiseSettings(
              advertiseMode: AdvertiseMode.advertiseModeLowPower,
              connectable: true,
              timeout: 1000,
            ),
          ),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['advertiseMode'], 0);
        expect(arguments['txPowerLevel'], 3);
        expect(arguments['connectable'], true);
        expect(arguments['timeout'], 1000);
      },
      skip: !Platform.isAndroid,
    );

    test(
      'prefixes advertise set parameters with set',
      () async {
        await blePeripheral.start(
          advertiseData: const AdvertiseDataCore(),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseSetParameters: AdvertiseSetParameters(
              connectable: true,
              interval: intervalMedium,
              primaryPhy: 1,
            ),
          ),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['setconnectable'], true);
        expect(arguments['setinterval'], intervalMedium);
        expect(arguments['setprimaryPhy'], 1);
      },
      skip: !Platform.isAndroid,
    );

    // Every platform reports ready on a successful start; the index has to
    // line up with PeripheralBluetoothState or the state comes back as
    // something else.
    test('maps the native ready code to ready', () async {
      response = PeripheralBluetoothState.ready.index;

      expect(
        await blePeripheral.start(advertiseData: const AdvertiseDataCore()),
        PeripheralBluetoothState.ready,
      );
      expect(PeripheralBluetoothState.ready.index, 8);
    });

    test(
      'prefixes the periodic data with periodic',
      () async {
        await blePeripheral.start(
          advertiseData: const AdvertiseDataCore(),
          androidSettings: AndroidAdvertiseSettings(
            advertiseSetParameters: const AdvertiseSetParameters(),
            periodicAdvertiseData: AndroidAdvertiseData(
              serviceUuid: 'FEAA',
              manufacturerId: 1234,
              manufacturerData: Uint8List.fromList([1, 2, 3]),
              includeDeviceName: true,
            ),
            periodicAdvertiseSettings: const PeriodicAdvertiseSettings(
              interval: 200,
              includeTxPowerLevel: true,
            ),
          ),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['periodicserviceUuid'], 'FEAA');
        expect(arguments['periodicmanufacturerId'], 1234);
        expect(arguments['periodicmanufacturerData'], const [1, 2, 3]);
        expect(arguments['periodicincludeDeviceName'], true);
        expect(arguments['periodicsettingsinterval'], 200);
        expect(arguments['periodicsettingsincludeTxPowerLevel'], true);
      },
      skip: !Platform.isAndroid,
    );

    test('omits the periodic keys when no periodic data is given', () async {
      await blePeripheral.start(advertiseData: const AdvertiseDataCore());

      final arguments = argumentsOf(calls.single);
      expect(
        arguments.keys.where((k) => (k! as String).startsWith('periodic')),
        isEmpty,
      );
    });

    // The native side switches the TX power flag on these keys, so they must
    // keep the names the models serialise to.
    test(
      'sends the tx power flags under the model key names',
      () async {
        await blePeripheral.start(
          advertiseData: const AndroidAdvertiseData(includeTxPowerLevel: true),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseSetParameters: AdvertiseSetParameters(
              includeTxPowerLevel: true,
            ),
            advertiseResponseData: AndroidAdvertiseData(
              includeTxPowerLevel: true,
            ),
          ),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['includeTxPowerLevel'], true);
        expect(arguments['responseincludeTxPowerLevel'], true);
        expect(arguments['setincludeTxPowerLevel'], true);
      },
      skip: !Platform.isAndroid,
    );

    // Android and Windows each carry their own timeout, since Android's applies
    // on the legacy path only and Windows has no per-set duration to end an
    // extended advertisement instead.
    test(
      'sends the Windows timeout under its own key',
      () async {
        await blePeripheral.start(
          advertiseData: const AdvertiseDataCore(),
          windowsSettings: const WindowsAdvertiseSettings(timeout: 400),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['windowstimeout'], 400);
        // Android's timeout must not stand in for it.
        expect(arguments['timeout'], isNull);
      },
      skip: !Platform.isWindows,
    );

    test(
      'sends the Android timeout unprefixed',
      () async {
        await blePeripheral.start(
          advertiseData: const AdvertiseDataCore(),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseSettings: AdvertiseSettings(timeout: 400),
          ),
        );

        final arguments = argumentsOf(calls.single);
        expect(arguments['timeout'], 400);
        expect(arguments['windowstimeout'], isNull);
      },
      skip: !Platform.isAndroid,
    );

    test('maps a null response to unknown', () async {
      expect(
        await blePeripheral.start(advertiseData: const AdvertiseDataCore()),
        PeripheralBluetoothState.unknown,
      );
    });
  });

  group('gatt server', () {
    // The characteristic uuids are the contract with the central, so they are
    // always sent from Dart. Deriving them natively made them differ per
    // platform, and change on every launch on Apple.
    test('sends the default characteristic uuids', () async {
      await blePeripheral.start(
        advertiseData: const AdvertiseDataCore(serviceUuid: 'abcd'),
        gattServer: const GattServerSettings(),
      );

      final gatt = argumentsOf(calls.single);
      expect(gatt['gattServiceUuid'], 'abcd');
      expect(gatt['gattCharacteristics'], [
        {
          'uuid': defaultTxCharacteristicUuid,
          // read, notify and indicate
          'properties': 1 | 8 | 16,
        },
        {
          'uuid': defaultRxCharacteristicUuid,
          // write and write without response
          'properties': 2 | 4,
        },
      ]);
    });

    test('the defaults are the Nordic UART Service characteristics', () {
      const nus = '6e40000';
      const suffix = '-b5a3-f393-e0a9-e50e24dcca9e';
      expect(nordicUartServiceUuid, '${nus}1$suffix');
      expect(defaultRxCharacteristicUuid, '${nus}2$suffix');
      expect(defaultTxCharacteristicUuid, '${nus}3$suffix');
    });

    test('honours explicit uuids', () async {
      await blePeripheral.start(
        advertiseData: const AdvertiseDataCore(serviceUuid: 'abcd'),
        gattServer: const GattServerSettings(
          serviceUuid: 'ef01',
          txCharacteristicUuid: 'ef02',
          rxCharacteristicUuid: 'ef03',
        ),
      );

      final arguments = argumentsOf(calls.single);
      // The served service may differ from the advertised one.
      expect(arguments['serviceUuid'], 'abcd');
      expect(arguments['gattServiceUuid'], 'ef01');
      expect(
        (arguments['gattCharacteristics']! as List)
            .map((dynamic c) => (c as Map)['uuid']),
        ['ef02', 'ef03'],
      );
    });

    test('serves a layout of its own in place of the tx and rx pair', () async {
      await blePeripheral.start(
        advertiseData: const AdvertiseDataCore(serviceUuid: '180d'),
        gattServer: const GattServerSettings(
          characteristics: [
            GattCharacteristic.notify('2a37'),
            GattCharacteristic(
              uuid: '2a39',
              properties: {GattCharacteristicProperty.write},
            ),
          ],
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['gattServiceUuid'], '180d');
      expect(arguments['gattCharacteristics'], [
        {'uuid': '2a37', 'properties': 1 | 8 | 16},
        {'uuid': '2a39', 'properties': 2},
      ]);
    });

    test('rejects a characteristic with no properties', () async {
      await expectLater(
        blePeripheral.start(
          advertiseData: const AdvertiseDataCore(serviceUuid: '180d'),
          gattServer: const GattServerSettings(
            characteristics: [
              GattCharacteristic(uuid: '2a37', properties: {}),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });

    test('rejects the same characteristic uuid twice', () async {
      await expectLater(
        blePeripheral.start(
          advertiseData: const AdvertiseDataCore(serviceUuid: '180d'),
          gattServer: const GattServerSettings(
            characteristics: [
              GattCharacteristic.notify('2A37'),
              GattCharacteristic.write('2a37'),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });

    test('sendData names the characteristic it delivers on', () async {
      await blePeripheral.sendData(
        Uint8List.fromList([1, 2, 3]),
        characteristicUuid: '2a37',
      );

      final arguments = argumentsOf(calls.single);
      expect(calls.single.method, 'sendData');
      expect(arguments['data'], Uint8List.fromList([1, 2, 3]));
      expect(arguments['characteristicUuid'], '2a37');
    });

    test('sendData leaves the characteristic to the platform by default',
        () async {
      await blePeripheral.sendData(Uint8List.fromList([4]));

      final arguments = argumentsOf(calls.single);
      expect(arguments['characteristicUuid'], isNull);
    });

    test('isSubscribedTo asks about one characteristic', () async {
      response = true;
      expect(await blePeripheral.isSubscribedTo('2a37'), isTrue);
      expect(calls.single.method, 'isSubscribed');
      expect(calls.single.arguments, '2a37');
    });

    test('sends no gatt keys when no server is asked for', () async {
      await blePeripheral.start(
        advertiseData: const AdvertiseDataCore(serviceUuid: 'abcd'),
      );

      final arguments = argumentsOf(calls.single);
      expect(
        arguments.keys.where((k) => (k! as String).startsWith('gatt')),
        isEmpty,
      );
    });

    test('rejects a server with no uuid to serve', () async {
      await expectLater(
        blePeripheral.start(
          advertiseData: const AdvertiseDataCore(),
          gattServer: const GattServerSettings(),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });
  });

  group('stop', () {
    test('maps the response to a state', () async {
      response = 5;
      expect(await blePeripheral.stop(), PeripheralBluetoothState.turnedOff);
      expect(calls.single.method, 'stop');
    });

    test('maps the native ready code to ready', () async {
      response = PeripheralBluetoothState.ready.index;
      expect(await blePeripheral.stop(), PeripheralBluetoothState.ready);
    });

    test('maps a null response to unknown', () async {
      expect(await blePeripheral.stop(), PeripheralBluetoothState.unknown);
    });
  });

  group('boolean getters', () {
    test('return the native value', () async {
      response = true;

      expect(await blePeripheral.isAdvertising, true);
      expect(await blePeripheral.isSupported, true);
      expect(await blePeripheral.isConnected, true);
      expect(await blePeripheral.isSubscribed, true);
      expect(await blePeripheral.isBluetoothOn, true);
      expect(calls.map((c) => c.method), [
        'isAdvertising',
        'isSupported',
        'isConnected',
        'isSubscribed',
        'isBluetoothOn',
      ]);
    });

    test('fall back to false when the native side returns null', () async {
      expect(await blePeripheral.isAdvertising, false);
      expect(await blePeripheral.isSupported, false);
      expect(await blePeripheral.isConnected, false);
      expect(await blePeripheral.isSubscribed, false);
      expect(await blePeripheral.isBluetoothOn, false);
    });
  });

  group('sendData', () {
    test('forwards the bytes', () async {
      final data = Uint8List.fromList([1, 2, 3]);

      await blePeripheral.sendData(data);

      expect(calls.single.method, 'sendData');
      expect(argumentsOf(calls.single)['data'], data);
    });
  });

  group('permissions', () {
    test(
      'map the response to a state',
      () async {
        response = 2;
        expect(
          await blePeripheral.requestPermission(),
          PeripheralBluetoothState.permanentlyDenied,
        );

        response = 1;
        expect(
          await blePeripheral.hasPermission(),
          PeripheralBluetoothState.denied,
        );

        expect(calls.map((c) => c.method), [
          'requestPermission',
          'hasPermission',
        ]);
      },
      skip: Platform.isWindows,
    );

    test(
      'map a null response to unknown',
      () async {
        expect(
          await blePeripheral.requestPermission(),
          PeripheralBluetoothState.unknown,
        );
        expect(
          await blePeripheral.hasPermission(),
          PeripheralBluetoothState.unknown,
        );
      },
      skip: Platform.isWindows,
    );

    // Windows has no Bluetooth permission of its own; the plugin asks for the
    // location permission that BLE requires and reduces it to granted/denied.
    test(
      'go through the location permission on Windows',
      () async {
        response = true;
        expect(
          await blePeripheral.requestPermission(),
          PeripheralBluetoothState.granted,
        );
        expect(calls.single.method, 'requestLocationPermission');

        response = false;
        expect(
          await blePeripheral.hasPermission(),
          PeripheralBluetoothState.denied,
        );
        expect(calls.last.method, 'hasLocationPermission');
      },
      skip: !Platform.isWindows,
    );
  });

  group('enableBluetooth', () {
    test('forwards askUser on Android only', () async {
      response = true;

      final enabled = await blePeripheral.enableBluetooth();

      if (Platform.isAndroid) {
        expect(enabled, true);
        expect(calls.single.arguments, true);
      } else if (Platform.isWindows) {
        // Windows uses the Radio API and ignores askUser.
        expect(enabled, true);
        expect(calls.single.arguments, isNull);
      } else {
        // Apple platforms cannot enable Bluetooth programmatically.
        expect(enabled, false);
        expect(calls, isEmpty);
      }
    });
  });

  group('settings shortcuts', () {
    test('invoke their channel method', () async {
      await blePeripheral.openBluetoothSettings();
      await blePeripheral.openAppSettings();

      expect(calls.map((c) => c.method), [
        'openBluetoothSettings',
        'openAppSettings',
      ]);
    });

    test(
      'the Windows-only ones are no-ops elsewhere',
      () async {
        await blePeripheral.openNearbyShareSettings();
        await blePeripheral.openLocationSettings();

        expect(await blePeripheral.isNearbyShareEnabled(), false);
        expect(calls, isEmpty);
      },
      skip: Platform.isWindows,
    );

    test(
      'the Windows-only ones reach the channel on Windows',
      () async {
        response = true;

        await blePeripheral.openNearbyShareSettings();
        await blePeripheral.openLocationSettings();
        expect(await blePeripheral.isNearbyShareEnabled(), true);

        expect(calls.map((c) => c.method), [
          'openNearbyShareSettings',
          'openLocationSettings',
          'isNearbyShareEnabled',
        ]);
      },
      skip: !Platform.isWindows,
    );
  });
}
