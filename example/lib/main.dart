/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// ignore: unnecessary_import
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() => runApp(const FlutterBlePeripheralExample());

class FlutterBlePeripheralExample extends StatefulWidget {
  const FlutterBlePeripheralExample({Key? key}) : super(key: key);

  @override
  FlutterBlePeripheralExampleState createState() =>
      FlutterBlePeripheralExampleState();
}


class FlutterBlePeripheralExampleState
    extends State<FlutterBlePeripheralExample> {
  static const String serviceUuid = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';
  static final CharacteristicDescription characteristic1 = CharacteristicDescription(uuid: "0x0123", value: Uint8List.fromList("hello".codeUnits), read: true);
  static final CharacteristicDescription characteristic2 = CharacteristicDescription(uuid: "00000002-A123-48CE-896B-4C76973373E6", value: Uint8List.fromList("world".codeUnits), write: true);
  static final CharacteristicDescription characteristic3 = CharacteristicDescription(uuid: "00000003-A123-48CE-896B-4C76973373E6", notify: true);

  final ServiceDescription service = ServiceDescription(
    uuid: serviceUuid,
    characteristics: [characteristic1, characteristic2, characteristic3],
  );

  final AdvertiseData advertiseData = AdvertiseData(
    serviceUuid: serviceUuid,
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
  );

  final AdvertiseSettings advertiseSettings = AdvertiseSettings(
    connectable: true,
    advertiseMode: AdvertiseMode.advertiseModeBalanced,
    txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
    timeout: 10000,
  );

  final AdvertiseSetParameters advertiseSetParameters =
      AdvertiseSetParameters();

  @override
  void initState() {
    super.initState();
    FlutterBlePeripheral().addService(service);
  }

  Future<void> _toggleAdvertise() async {
    if (FlutterBlePeripheral().isAdvertising) {
      await FlutterBlePeripheral().stop();
    } else {
      await FlutterBlePeripheral().start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );
    }
  }

  Future<void> _toggleAdvertiseSet() async {
    if (FlutterBlePeripheral().isAdvertising) {
      await FlutterBlePeripheral().stop();
    } else {
      await FlutterBlePeripheral().start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
  }

  Future<void> _requestPermissions() async {
    final hasPermission = await FlutterBlePeripheral().requestPermission();
    if (hasPermission == PermissionState.granted) {
      _messangerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'State: $hasPermission!',
          ),
        ),
      );
    } else {
      _messangerKey.currentState?.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "We don't have permissions, requesting now!",
          ),
        ),
      );

      await _requestPermissions();
    }
  }

  Future<void> _hasPermissions() async {
    final hasPermissions = await FlutterBlePeripheral().hasPermission();
    _messangerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Has permission: $hasPermissions'),
        backgroundColor: hasPermissions == PermissionState.granted
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  Widget button({required void Function()? onPressed, required String label}) => MaterialButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: Theme.of(context)
          .primaryTextTheme
          .labelLarge!
          .copyWith(color: Colors.blue),
    ),
  );

  final _messangerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messangerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter BLE Peripheral'),
        ),
        body: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20.0),
            children: <Widget>[
              FutureBuilder(
                future: FlutterBlePeripheral().isSupported,
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  return Center(child: Text('Is supported: ${snapshot.data ?? '...'}'),);
                },
              ),
              StreamBuilder<PeripheralState>(
                stream: FlutterBlePeripheral().onPeripheralStateChanged,
                initialData: FlutterBlePeripheral().state,
                builder: (BuildContext context, AsyncSnapshot<PeripheralState> snapshot) {
                  return Center(child: Text('State: ${describeEnum(snapshot.data!)}',));
                },
              ),
              const Center(child: Text('UUID: $serviceUuid'),),
              button(
                onPressed: _toggleAdvertise,
                label: 'Toggle advertising',
              ),
              button(
                onPressed: () async {
                  await FlutterBlePeripheral().start(
                    advertiseData: advertiseData,
                    advertiseSettings: advertiseSettings,
                  );
                },
                label: 'Start advertising',
              ),
              button(
                onPressed: () async {
                  await FlutterBlePeripheral().stop();
                },
                label: 'Stop advertising',
              ),
              button(
                onPressed: _toggleAdvertiseSet,
                label: 'Toggle advertising set for 1 second',
              ),
              button(
                onPressed: () async {
                  final bool enabled = await FlutterBlePeripheral()
                      .enableBluetooth(askUser: false);
                  if (enabled) {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Bluetooth enabled!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Bluetooth not enabled!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                label: 'Enable Bluetooth (ANDROID)',
              ),
              button(
                onPressed: () async {
                  final bool enabled =
                      await FlutterBlePeripheral().enableBluetooth();
                  if (enabled) {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Bluetooth enabled!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Bluetooth not enabled!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                label: 'Ask if enable Bluetooth (ANDROID)',
              ),
              button(
                onPressed: _requestPermissions,
                label: 'Request Permissions',
              ),
              button(
                onPressed: _hasPermissions,
                label: 'Has permissions',
              ),
              button(
                onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
                label: 'Open bluetooth settings',
              ),
              const SizedBox(height: 20),
              TextFormField( //Characteristic 1 (read)
                initialValue: String.fromCharCodes(characteristic1.value),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onFieldSubmitted: (val) => FlutterBlePeripheral().write(characteristic1.uuid, Uint8List.fromList(val.codeUnits)),
              ),
              const SizedBox(height: 20),
              StreamBuilder<Uint8List>( //Characteristic 2 (write)
                stream: FlutterBlePeripheral().getDataReceived
                    .where((p) => p.characteristicUUID == characteristic2.uuid)
                    .map((p) => p.value),
                initialData: characteristic2.value,
                builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
                  String data = String.fromCharCodes(snapshot.data!);
                  return TextFormField(
                    key: Key(data),
                    initialValue: data,
                    enabled: false,
                    readOnly: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  );
                },
              ),
              const SizedBox(height: 20),
              TextFormField( //Characteristic 3 (notify)
                initialValue: String.fromCharCodes(characteristic3.value),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onFieldSubmitted: (val) => FlutterBlePeripheral().write(characteristic3.uuid, Uint8List.fromList(val.codeUnits)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
