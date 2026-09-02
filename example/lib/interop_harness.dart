// The peripheral half of the interop harness.
//
// It is not a demo. It starts advertising and serving the GATT service as soon
// as it launches, echoes back anything a central writes, and reports what it
// sees on stdout as `HARNESS|` lines for `tool/interop_test.dart` in
// flutter_ble_central to read. Run it with:
//
//     flutter run -d <device> -t lib/interop_harness.dart
//
// The other half is `example/lib/interop_harness.dart` in flutter_ble_central.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

/// The service the harness serves. The central half looks for exactly this, and
/// it is the one both example apps use, so a hand-run example also finds it.
const harnessServiceUuid = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';

/// The name advertised alongside it, so a person watching a scanner can tell
/// the harness apart from the example app.
const harnessLocalName = 'BLE Interop';

void main() => runApp(const InteropHarnessApp());

/// Names this platform the way the report does.
String get platformName {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

/// One line of the protocol the orchestrator reads.
///
/// Anything not prefixed this way is ignored by it, so ordinary framework
/// logging on the same stream does no harm.
void emit(String kind, List<String> fields) {
  // Stdout is the whole point of the harness: the orchestrator reads it.
  // ignore: avoid_print
  print('HARNESS|$kind|${fields.join('|')}');
}

/// The peripheral half of the harness.
class InteropHarnessApp extends StatefulWidget {
  /// Creates the harness app.
  const InteropHarnessApp({super.key});

  @override
  State<InteropHarnessApp> createState() => _InteropHarnessAppState();
}

class _InteropHarnessAppState extends State<InteropHarnessApp> {
  final _peripheral = FlutterBlePeripheral();
  final _log = <String>[];

  final _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_peripheral.stop());
    super.dispose();
  }

  void _record(String kind, List<String> fields) {
    emit(kind, fields);
    if (mounted) {
      setState(() => _log.insert(0, '$kind  ${fields.join('  ')}'));
    }
  }

  /// Brings the peripheral up and leaves it up. Everything after this is driven
  /// by the central.
  Future<void> _run() async {
    try {
      final supported = await _peripheral.isSupported;
      _record('EVENT', ['supported', '$supported']);
      if (!supported) {
        _record('FATAL', ['This device cannot act as a BLE peripheral']);
        return;
      }

      if (!await _awaitPermission()) return;

      _listen();

      await _peripheral.start(
        advertiseData: const AdvertiseDataCore(
          serviceUuid: harnessServiceUuid,
          localName: harnessLocalName,
        ),
        gattServer: const GattServerSettings(),
        androidSettings: const AndroidAdvertiseSettings(
          advertiseSettings: AdvertiseSettings(connectable: true),
        ),
      );

      _record('READY', [platformName, harnessServiceUuid]);
    } on Object catch (error) {
      _record('FATAL', ['$error']);
    }
  }

  /// Asks for Bluetooth and waits for whoever is at the device to answer.
  ///
  /// The request answers before the system dialog is dismissed, so the first
  /// run on a device would otherwise fail on a prompt nobody had reached yet.
  Future<bool> _awaitPermission() async {
    var state = await _peripheral.requestPermission();
    _record('EVENT', ['permission', state.name]);

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (!_granted(state) && DateTime.now().isBefore(deadline)) {
      _record('WAITING', ['Allow Bluetooth on this device to continue']);
      await Future<void>.delayed(const Duration(seconds: 2));
      state = await _peripheral.hasPermission();
    }

    if (!_granted(state)) {
      _record('FATAL', ['Bluetooth permission is ${state.name}']);
      return false;
    }
    _record('EVENT', ['permission', state.name]);
    return true;
  }

  static bool _granted(PeripheralBluetoothState state) =>
      state == PeripheralBluetoothState.granted ||
      state == PeripheralBluetoothState.ready;

  /// Follows what the central does to this peripheral, and echoes its writes.
  void _listen() {
    final stateStream = _peripheral.onPeripheralStateChanged;
    if (stateStream != null) {
      _subscriptions.add(
        stateStream.listen((state) => _record('EVENT', ['state', state.name])),
      );
    }

    _subscriptions.add(
      _peripheral.onMtuChanged.listen(
        (mtu) => _record('EVENT', ['mtu', '$mtu']),
      ),
    );

    _subscriptions.add(
      _peripheral.onSubscriptionChanged.listen(
        (subscribed) => _record('EVENT', ['subscribed', '$subscribed']),
      ),
    );

    // The echo is what lets the central prove a write arrived and a
    // notification comes back, in one round trip.
    _subscriptions.add(
      _peripheral.onDataReceived.listen((data) async {
        _record('EVENT', ['received', _hex(data)]);
        try {
          await _peripheral.sendData(data);
          _record('EVENT', ['echoed', _hex(data)]);
        } on Object catch (error) {
          _record('EVENT', ['echo_failed', '$error']);
        }
      }),
    );
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: Scaffold(
        appBar: AppBar(title: Text('Interop harness — $platformName')),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _log.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              _log[index],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
