# flutter_ble_peripheral_example

Demonstrates how to use the flutter_ble_peripheral plugin.

## Example

```dart
/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() => runApp(FlutterBlePeripheralExample());

class FlutterBlePeripheralExample extends StatefulWidget {
  @override
  _FlutterBlePeripheralExampleState createState() =>
      _FlutterBlePeripheralExampleState();
}

class _FlutterBlePeripheralExampleState
    extends State<FlutterBlePeripheralExample> {
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  final AdvertiseData _data = AdvertiseData();
  bool _isBroadcasting = false;

  @override
  void initState() {
    super.initState();
    setState(() {
      _data.includeDeviceName = false;
      _data.uuid = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';
      _data.manufacturerId = 1234;
      _data.manufacturerData = [1, 2, 3, 4, 5, 6];
      _data.txPowerLevel = AdvertisePower.ADVERTISE_TX_POWER_ULTRA_LOW;
      _data.advertiseMode = AdvertiseMode.ADVERTISE_MODE_LOW_LATENCY;
    });
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    var isAdvertising = await blePeripheral.isAdvertising();
    setState(() {
      _isBroadcasting = isAdvertising;
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
              Text('Is advertising: $_isBroadcasting'),
              StreamBuilder(
                  stream: blePeripheral.getAdvertisingStateChange(),
                  initialData: 'Advertisement not started.',
                  builder:
                      (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    return Text('Is advertising stream: ${snapshot.data}');
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
```
