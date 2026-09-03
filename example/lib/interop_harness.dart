// The peripheral half of the interop harness.
//
// It is not a demo. It starts advertising and serving the GATT service as soon
// as it launches, echoes back anything a central writes, and reports what it
// sees on stdout as `HARNESS|` lines for `tool/interop_test.dart` in
// flutter_ble_central to read.
//
// Two things it cannot cover, because a scripted run cannot background or kill
// an app and then talk to it: advertising from a foreground service with no
// activity attached, and the state restoration that hands a relaunched app its
// advertisement back. Both stay manual.
//
// Run it with:
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

/// A third characteristic, served alongside the default TX and RX pair.
///
/// It carries three things the pair cannot prove on its own: that a layout of
/// more than two characteristics is served, that one characteristic can be both
/// written to and notified on, which is the shape BLE-MIDI needs, and that a 16
/// bit uuid reaches the same characteristic as its 128 bit form. It is declared
/// here in the short form and reported back by the plugin in the long one.
const harnessComboUuidShort = 'ff01';

/// [harnessComboUuidShort] as the platform reports it back.
const harnessComboUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

/// A fourth characteristic, readable and nothing else.
///
/// The other three all notify, which on some platforms is what gets a read
/// answered at all, so a characteristic that only reads is the one that proves
/// a plain read is served on its own.
const harnessReadOnlyUuidShort = 'ff02';

/// [harnessReadOnlyUuidShort] as the platform reports it back.
///
/// Nothing seeds it: `sendData` only takes a characteristic that notifies, so
/// what a read of it returns is the platform's own empty default. That a read
/// is answered at all is the point of it.
const harnessReadOnlyUuid = '0000ff02-0000-1000-8000-00805f9b34fb';

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
        gattServer: const GattServerSettings(
          characteristics: [
            GattCharacteristic.notify(defaultTxCharacteristicUuid),
            GattCharacteristic.write(defaultRxCharacteristicUuid),
            GattCharacteristic(
              uuid: harnessComboUuidShort,
              properties: {
                GattCharacteristicProperty.read,
                GattCharacteristicProperty.write,
                GattCharacteristicProperty.writeWithoutResponse,
                GattCharacteristicProperty.notify,
                GattCharacteristicProperty.indicate,
              },
            ),
            GattCharacteristic(
              uuid: harnessReadOnlyUuidShort,
              properties: {GattCharacteristicProperty.read},
            ),
          ],
        ),
        androidSettings: const AndroidAdvertiseSettings(
          advertiseSettings: AdvertiseSettings(connectable: true),
        ),
      );

      // What the central should find, so a discovery that disagrees is the
      // plugin's fault rather than a stale harness.
      _record('LAYOUT', [
        defaultTxCharacteristicUuid,
        defaultRxCharacteristicUuid,
        harnessComboUuid,
        harnessReadOnlyUuid,
      ]);

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

    // Per characteristic, and asked back through isSubscribedTo, so the two
    // ways of answering the same question are checked against each other.
    _subscriptions.add(
      _peripheral.onCharacteristicSubscriptionChanged.listen((event) async {
        _record('EVENT', [
          'subscribed_to',
          event.characteristicUuid,
          '${event.subscribed}',
        ]);
        try {
          final live = await _peripheral.isSubscribedTo(
            event.characteristicUuid,
          );
          _record('EVENT', [
            'is_subscribed_to',
            event.characteristicUuid,
            '$live',
          ]);
        } on Object catch (error) {
          _record('EVENT', ['is_subscribed_to_failed', '$error']);
        }
      }),
    );

    // The echo is what lets the central prove a write arrived and a
    // notification comes back, in one round trip. It goes out on the
    // characteristic that was written where that one notifies, so the central
    // can tell per-characteristic routing from a single shared channel; a
    // write-only characteristic has nowhere to answer, and those go back on TX.
    _subscriptions.add(
      _peripheral.onGattWrite.listen((write) async {
        final source = write.characteristicUuid.toLowerCase();
        _record('EVENT', ['received', source, _hex(write.data)]);

        final target = source == harnessComboUuid
            ? harnessComboUuid
            : defaultTxCharacteristicUuid;
        try {
          await _peripheral.sendData(write.data, characteristicUuid: target);
          _record('EVENT', ['echoed', target, _hex(write.data)]);
        } on Object catch (error) {
          _record('EVENT', ['echo_failed', target, '$error']);
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
