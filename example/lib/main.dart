/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// ignore: unnecessary_import
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
  final AdvertiseData advertiseData = AdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
  );

  // final advertiseSettings = AdvertiseSettings(
  //   advertiseMode: AdvertiseMode.advertiseModeBalanced,
  //   txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
  //   timeout: 3000,
  // );

  final AdvertiseSetParameters advertiseSetParameters =
      AdvertiseSetParameters();

  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final isSupported = await FlutterBlePeripheral().isSupported;
    setState(() {
      _isSupported = isSupported;
    });
  }

  Future<void> _toggleAdvertise() async {
    if (await FlutterBlePeripheral().isAdvertising) {
      await FlutterBlePeripheral().stop();
    } else {
      await FlutterBlePeripheral().start(advertiseData: advertiseData);
    }
  }

  Future<void> _toggleAdvertiseSet() async {
    if (await FlutterBlePeripheral().isAdvertising) {
      await FlutterBlePeripheral().stop();
    } else {
      await FlutterBlePeripheral().start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
  }

  Future<void> _requestPermissions() async {
    final hasPermission = await FlutterBlePeripheral().hasPermission();
    switch (hasPermission) {
      case BluetoothPeripheralState.denied:
        _messangerKey.currentState?.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "We don't have permissions, requesting now!",
            ),
          ),
        );

        await _requestPermissions();
        break;
      default:
        _messangerKey.currentState?.showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'State: $hasPermission!',
            ),
          ),
        );
        break;
    }
  }

  Future<void> _hasPermissions() async {
    final hasPermissions = await FlutterBlePeripheral().hasPermission();
    _messangerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Has permission: $hasPermissions'),
        backgroundColor: hasPermissions == BluetoothPeripheralState.granted
            ? Colors.green
            : Colors.red,
      ),
    );
  }

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Is supported: $_isSupported'),
              StreamBuilder(
                stream: FlutterBlePeripheral().onPeripheralStateChanged,
                initialData: PeripheralState.unknown,
                builder:
                    (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  return Text(
                    'State: ${describeEnum(snapshot.data as PeripheralState)}',
                  );
                },
              ),
              // StreamBuilder(
              //     stream: FlutterBlePeripheral().getDataReceived(),
              //     initialData: 'None',
              //     builder:
              //         (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              //       return Text('Data received: ${snapshot.data}');
              //     },),
              Text('Current UUID: ${advertiseData.serviceUuid}'),
              MaterialButton(
                onPressed: _toggleAdvertise,
                child: Text(
                  'Toggle advertising',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  await FlutterBlePeripheral().start(
                    advertiseData: advertiseData,
                    advertiseSetParameters: advertiseSetParameters,
                  );
                },
                child: Text(
                  'Start advertising',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  await FlutterBlePeripheral().stop();
                },
                child: Text(
                  'Stop advertising',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _toggleAdvertiseSet,
                child: Text(
                  'Toggle advertising set for 1 second',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              StreamBuilder(
                stream: FlutterBlePeripheral().onPeripheralStateChanged,
                initialData: PeripheralState.unknown,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<PeripheralState> snapshot,
                ) {
                  return MaterialButton(
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
                    child: Text(
                      'Enable Bluetooth (ANDROID)',
                      style: Theme.of(context)
                          .primaryTextTheme
                          .labelLarge!
                          .copyWith(color: Colors.blue),
                    ),
                  );
                },
              ),
              MaterialButton(
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
                child: Text(
                  'Ask if enable Bluetooth (ANDROID)',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _requestPermissions,
                child: Text(
                  'Request Permissions',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _hasPermissions,
                child: Text(
                  'Has permissions',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
                child: Text(
                  'Open bluetooth settings',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
