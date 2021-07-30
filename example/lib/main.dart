/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() => runApp(const FlutterBlePeripheralExample());

class FlutterBlePeripheralExample extends StatefulWidget {
  const FlutterBlePeripheralExample({Key? key}) : super(key: key);

  @override
  _FlutterBlePeripheralExampleState createState() =>
      _FlutterBlePeripheralExampleState();
}

class _FlutterBlePeripheralExampleState
    extends State<FlutterBlePeripheralExample> {
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  final AdvertiseData _data = AdvertiseData();

  bool _isBroadcasting = false;
  bool? _isSupported;

  @override
  void initState() {
    super.initState();
    setState(() {
      _data.includeDeviceName = false;
      _data.uuid = '8ebdb2f3-7817-45c9-95c5-c5e9031aaa47';
      _data.manufacturerId = 1234;
      _data.timeout = 1000;
      _data.manufacturerData = [1, 2, 3, 4, 5, 6];
      _data.txPowerLevel = AdvertisePower.ADVERTISE_TX_POWER_MEDIUM;
      _data.advertiseMode = AdvertiseMode.ADVERTISE_MODE_BALANCED;
      _data.connectable = true;
      _data.includeDeviceName = false;
    });
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final isSupported = await blePeripheral.isSupported();
    setState(() {
      _isSupported = isSupported;
    });
  }

  void _toggleAdvertise() async {
    if (await blePeripheral.isAdvertising()) {
      await blePeripheral.stop();
      setState(() {
        _isBroadcasting = false;
      });
    } else {
      await blePeripheral.start(_data);
      setState(() {
        _isBroadcasting = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter BLE Peripheral'),
        ),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
              StreamBuilder(
                  stream: blePeripheral.getStateChanged(),
                  initialData: 'State: ?',
                  builder:
                      (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    return Text('State: ${snapshot.data}');
                  }),
              StreamBuilder(
                  stream: blePeripheral.getDataReceived(),
                  initialData: 'Data not received.',
                  builder:
                      (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    return Text('Data received: ${snapshot.data}');
                  }),
              Text('Current uuid is ${_data.uuid}'),
              MaterialButton(
                  onPressed: _toggleAdvertise,
                  child: Text(
                    'Toggle advertising',
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button!
                        .copyWith(color: Colors.blue),
                  )),
            ])),
      ),
    );
  }
}
