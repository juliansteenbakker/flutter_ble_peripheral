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
    test('sends the advertise data and the default settings', () async {
      response = 8;

      final state = await blePeripheral.start(
        advertiseData: AdvertiseData(
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
      // Defaults from AdvertiseSettings, merged into the same flat payload.
      expect(arguments['advertiseMode'], 2);
      expect(arguments['txPowerLevel'], 1);
      expect(arguments['timeout'], 400);
      expect(state, BluetoothPeripheralState.ready);
    });

    // The bytes are sent twice: once encoded by the converter and once raw, so
    // that the native side can read a ByteArray directly.
    test('sends the manufacturer data raw as well', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      await blePeripheral.start(
        advertiseData: AdvertiseData(manufacturerData: bytes),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['manufacturerData'], const [1, 2, 3]);
      expect(arguments['manufacturerDataBytes'], bytes);
    });

    // serviceUuids has to reach the channel even when serviceUuid is null, so
    // that Android can advertise the list on its own.
    test('sends serviceUuids without a singular serviceUuid', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseData(
          serviceUuids: const ['5b0e0100-0100-1000-8000-00805f9b34fb', 'A1B2'],
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
    test('prefixes the response data with response', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseData(serviceUuid: 'abcd'),
        advertiseResponseData: AdvertiseData(
          serviceUuid: 'ef01',
          manufacturerId: 1234,
          manufacturerData: Uint8List.fromList([1, 2, 3]),
          serviceDataUuid: 'FEAA',
          serviceData: const [4, 5],
          includeDeviceName: true,
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
    });

    test('honours explicit advertise settings', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseData(),
        advertiseSettings: AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeLowPower,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          connectable: true,
          timeout: 1000,
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['advertiseMode'], 0);
      expect(arguments['txPowerLevel'], 3);
      expect(arguments['connectable'], true);
      expect(arguments['timeout'], 1000);
    });

    test('prefixes advertise set parameters with set', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseData(),
        advertiseSetParameters: AdvertiseSetParameters(
          connectable: true,
          interval: intervalMedium,
          primaryPhy: 1,
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['setconnectable'], true);
      expect(arguments['setinterval'], intervalMedium);
      expect(arguments['setprimaryPhy'], 1);
    });

    // Every platform reports ready on a successful start; the index has to
    // line up with BluetoothPeripheralState or the state comes back as
    // something else.
    test('maps the native ready code to ready', () async {
      response = BluetoothPeripheralState.ready.index;

      expect(
        await blePeripheral.start(advertiseData: AdvertiseData()),
        BluetoothPeripheralState.ready,
      );
      expect(BluetoothPeripheralState.ready.index, 8);
    });

    test('prefixes the periodic data with periodic', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseData(),
        advertisePeriodicData: AdvertiseData(
          serviceUuid: 'FEAA',
          manufacturerId: 1234,
          manufacturerData: Uint8List.fromList([1, 2, 3]),
          includeDeviceName: true,
        ),
        periodicAdvertiseSettings: PeriodicAdvertiseSettings(
          interval: 200,
          includeTxPowerLevel: true,
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['periodicserviceUuid'], 'FEAA');
      expect(arguments['periodicmanufacturerId'], 1234);
      expect(arguments['periodicmanufacturerData'], const [1, 2, 3]);
      expect(arguments['periodicincludeDeviceName'], true);
      expect(arguments['periodicsettingsinterval'], 200);
      expect(arguments['periodicsettingsincludeTxPowerLevel'], true);
    });

    test('omits the periodic keys when no periodic data is given', () async {
      await blePeripheral.start(advertiseData: AdvertiseData());

      final arguments = argumentsOf(calls.single);
      expect(
        arguments.keys.where((k) => (k! as String).startsWith('periodic')),
        isEmpty,
      );
    });

    // The native side switches the TX power flag on these keys, so they must
    // keep the names the models serialise to.
    test('sends the tx power flags under the model key names', () async {
      await blePeripheral.start(
        advertiseData: AdvertiseData(includePowerLevel: true),
        advertiseResponseData: AdvertiseData(includePowerLevel: true),
        advertiseSetParameters: AdvertiseSetParameters(
          includeTxPowerLevel: true,
        ),
      );

      final arguments = argumentsOf(calls.single);
      expect(arguments['includePowerLevel'], true);
      expect(arguments['responseincludePowerLevel'], true);
      expect(arguments['setincludeTxPowerLevel'], true);
    });

    test('maps a null response to unknown', () async {
      expect(
        await blePeripheral.start(advertiseData: AdvertiseData()),
        BluetoothPeripheralState.unknown,
      );
    });
  });

  group('stop', () {
    test('maps the response to a state', () async {
      response = 5;
      expect(await blePeripheral.stop(), BluetoothPeripheralState.turnedOff);
      expect(calls.single.method, 'stop');
    });

    test('maps the native ready code to ready', () async {
      response = BluetoothPeripheralState.ready.index;
      expect(await blePeripheral.stop(), BluetoothPeripheralState.ready);
    });

    test('maps a null response to unknown', () async {
      expect(await blePeripheral.stop(), BluetoothPeripheralState.unknown);
    });
  });

  group('boolean getters', () {
    test('return the native value', () async {
      response = true;

      expect(await blePeripheral.isAdvertising, true);
      expect(await blePeripheral.isSupported, true);
      expect(await blePeripheral.isConnected, true);
      expect(await blePeripheral.isBluetoothOn, true);
      expect(calls.map((c) => c.method), [
        'isAdvertising',
        'isSupported',
        'isConnected',
        'isBluetoothOn',
      ]);
    });

    test('fall back to false when the native side returns null', () async {
      expect(await blePeripheral.isAdvertising, false);
      expect(await blePeripheral.isSupported, false);
      expect(await blePeripheral.isConnected, false);
      expect(await blePeripheral.isBluetoothOn, false);
    });
  });

  group('sendData', () {
    test('forwards the bytes', () async {
      final data = Uint8List.fromList([1, 2, 3]);

      await blePeripheral.sendData(data);

      expect(calls.single.method, 'sendData');
      expect(calls.single.arguments, data);
    });
  });

  group('permissions', () {
    test(
      'map the response to a state',
      () async {
        response = 2;
        expect(
          await blePeripheral.requestPermission(),
          BluetoothPeripheralState.permanentlyDenied,
        );

        response = 1;
        expect(
          await blePeripheral.hasPermission(),
          BluetoothPeripheralState.denied,
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
          BluetoothPeripheralState.unknown,
        );
        expect(
          await blePeripheral.hasPermission(),
          BluetoothPeripheralState.unknown,
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
          BluetoothPeripheralState.granted,
        );
        expect(calls.single.method, 'requestLocationPermission');

        response = false;
        expect(
          await blePeripheral.hasPermission(),
          BluetoothPeripheralState.denied,
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
