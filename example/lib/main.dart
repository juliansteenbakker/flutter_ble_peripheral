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
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();

  final AdvertiseData advertiseData = AdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
  );

  final AdvertiseSettings advertiseSettings = AdvertiseSettings(
    advertiseMode: AdvertiseMode.advertiseModeBalanced,
    txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
    timeout: 3000,
  );

  final AdvertiseSetParameters advertiseSetParameters = AdvertiseSetParameters(
    txPowerLevel: txPowerMax,
  );

  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final isSupported = await blePeripheral.isSupported;
    setState(() {
      _isSupported = isSupported;
    });
  }

  Future<void> _toggleAdvertise() async {
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    } else {
      await blePeripheral.start(advertiseData: advertiseData);
    }
  }

  Future<void> _toggleAdvertiseSet() async {
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    } else {
      await blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await blePeripheral.requestPermission();
    if (statuses == null) {
      _messangerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while requesting permissions...'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    for (final status in statuses.keys) {
      if (statuses[status] == PermissionState.granted) {
        debugPrint('$status permission granted');
        _messangerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Permissions granted!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (statuses[status] == PermissionState.denied) {
        debugPrint(
          '$status denied. Show a dialog with a reason and again ask for the permission.',
        );
        _messangerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Permissions denied, but if we explain it to the user, we can request it again.'),
            backgroundColor: Colors.yellow,
          ),
        );
      } else if (statuses[status] == PermissionState.permanentlyDenied) {
        debugPrint(
          '$status permanently denied. Take the user to the settings page.',
        );
        _messangerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Permissions permanently denied. Take the user to the settings screen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // final Map<Permission, PermissionStatus> statuses = await [
    //   Permission.bluetooth,
    //   Permission.bluetoothAdvertise,
    //   Permission.location,
    // ].request();
    // for (final status in statuses.keys) {
    //   if (statuses[status] == PermissionStatus.granted) {
    //     debugPrint('$status permission granted');
    //   } else if (statuses[status] == PermissionStatus.denied) {
    //     debugPrint(
    //       '$status denied. Show a dialog with a reason and again ask for the permission.',
    //     );
    //   } else if (statuses[status] == PermissionStatus.permanentlyDenied) {
    //     debugPrint(
    //       '$status permanently denied. Take the user to the settings page.',
    //     );
    //   }
    // }
  }

  Future<void> _hasPermissions() async {
    final hasPermissions = await blePeripheral.hasPermission();
    _messangerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Has permission: $hasPermissions'),
        backgroundColor: hasPermissions != null && hasPermissions.isEmpty ? Colors.green : Colors.red,
      ),
    );

    // for (final status in statuses.keys) {
    //   if (statuses[status] == PermissionStatus.granted) {
    //     debugPrint('$status permission granted');
    //   } else if (statuses[status] == PermissionStatus.denied) {
    //     debugPrint(
    //       '$status denied. Show a dialog with a reason and again ask for the permission.',
    //     );
    //   } else if (statuses[status] == PermissionStatus.permanentlyDenied) {
    //     debugPrint(
    //       '$status permanently denied. Take the user to the settings page.',
    //     );
    //   }
    // }
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
                stream: blePeripheral.onPeripheralStateChanged,
                initialData: PeripheralState.unknown,
                builder:
                    (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  return Text(
                    'State: ${describeEnum(snapshot.data as PeripheralState)}',
                  );
                },
              ),
              // StreamBuilder(
              //     stream: blePeripheral.getDataReceived(),
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
                stream: blePeripheral.onPeripheralStateChanged,
                initialData: PeripheralState.unknown,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<PeripheralState> snapshot,
                ) {
                  return MaterialButton(
                    onPressed: () async {
                      final bool enabled = await blePeripheral.enableBluetooth(askUser: false);
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
                  final bool enabled = await blePeripheral.enableBluetooth();
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
                onPressed: () => blePeripheral.openBluetoothSettings(),
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
