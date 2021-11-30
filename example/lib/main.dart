/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final AdvertiseData _data = AdvertiseData(
    uuid: '8ebdb2f3-7817-45c9-95c5-c5e9031aaa47',
    manufacturerId: 1234,
    manufacturerData: [1, 2, 3, 4, 5, 6],
  );

  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
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
    } else {
      await blePeripheral.start(_data);
    }
  }

  void _requestPermissions() async {
    // var platform  =Platform.version;
    // if (Platform.isAndroid) {

      await Permission.bluetooth.shouldShowRequestRationale;
      // You can request multiple permissions at once.
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();
      for (final status in statuses.keys) {
        if (statuses[status] == PermissionStatus.granted) {
          print('$status permission granted');
        } else if (statuses[status] == PermissionStatus.denied) {
          print('$status denied. Show a dialog with a reason and again ask for the permission.');
        } else if (statuses[status] == PermissionStatus.permanentlyDenied) {
          print('$status permanently denied. Take the user to the settings page.');
        }
      }
      // final sdkInt = androidInfo.version.sdkInt;
      // var status = await Permission.camera.status;
    // }

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
                  Text('Is supported: $_isSupported'),
              StreamBuilder(
                  stream: blePeripheral.getStateChanged(),
                  initialData: PeripheralState.unknown,
                  builder:
                      (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    return Text('State: ${snapshot.data}');
                  }),
              StreamBuilder(
                  stream: blePeripheral.getDataReceived(),
                  initialData: 'None',
                  builder:
                      (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    return Text('Data received: ${snapshot.data}');
                  }),
              Text('Current UUID: ${_data.uuid}'),
              MaterialButton(
                  onPressed: _toggleAdvertise,
                  child: Text(
                    'Toggle advertising',
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button!
                        .copyWith(color: Colors.blue),
                  )),
                  MaterialButton(
                      onPressed: _requestPermissions,
                      child: Text(
                        'Request Permissions',
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
