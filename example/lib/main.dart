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
    txPowerLevel: txPowerMedium,
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
      final error = await blePeripheral.start(advertiseData: advertiseData);
      if (error != null) {
        _messangerKey.currentState!.showSnackBar(
          SnackBar(
            content: Text('Error: ${error.errorCode}, ${error.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }

    }
  }

  Future<void> _toggleAdvertiseSet() async {
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    } else {
      final error = await blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
      if (error != null) {
        _messangerKey.currentState!.showSnackBar(
          SnackBar(
            content: Text('Error: ${error.errorCode}, ${error.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                  final state = snapshot.data as PeripheralState?;
                  return Text(
                    'State: ${state != null ? describeEnum(state) : ''}',
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
                      .button!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _toggleAdvertiseSet,
                child: Text(
                  'Toggle advertising set for 1 second',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .button!
                      .copyWith(color: Colors.blue),
                ),
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
                  'Ask if enable Bluetooth',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .button!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  final bool enabled = await FlutterBlePeripheral().requestPermission();
                  if (enabled) {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Permissions granted!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Permissions denied!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(
                  'Request Permissions',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .button!
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
