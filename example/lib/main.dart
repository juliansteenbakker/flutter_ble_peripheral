/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/data.dart';
import 'package:flutter_ble_peripheral/main.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  AdvertiseData _data = AdvertiseData();
  bool _isBroadcasting = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    bool isAdvertising = await blePeripheral.isAdvertising();
    setState(() {
      _isBroadcasting = isAdvertising;
      _data.includeDeviceName = false;
      _data.uuid = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';
      _data.manufacturerId = 1234;
      _data.manufacturerData = [
        1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    });
  }

  void _toggleAdvertise() async {
    if (await blePeripheral.isAdvertising()) {
      blePeripheral.stop();
      setState(() {
        _isBroadcasting = false;
      });
    } else {
      blePeripheral.start(_data);
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
              Text('Is advertising: ' + _isBroadcasting.toString()),
              Text('Current uuid is ' + _data.uuid),
              FlatButton(
                  onPressed: () => _toggleAdvertise(),
                  child: Text(
                    'Toggle advertising',
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.blue),
                  )),
            ])),
      ),
    );
  }
}