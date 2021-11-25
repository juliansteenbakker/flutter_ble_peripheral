import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BleStatusScreen extends StatelessWidget {
  const BleStatusScreen({required this.status, Key? key}) : super(key: key);

  final PeripheralState status;
  // idle, advertising, connected, unsupported, unauthorized }
  String determineText(PeripheralState status) {
    switch (status) {
      case PeripheralState.unsupported:
        return "This device does not support Bluetooth";
      case PeripheralState.unauthorized:
        return "Authorize the BlePeripheral example app to use Bluetooth and location";
      // case PeripheralState.:
      //   return "Bluetooth is powered off on your device turn it on";
      // case PeripheralState.unauthorized:
      //   return "Enable location services";
      case PeripheralState.idle:
        return "Bluetooth is up and running";
      default:
        return "Waiting to fetch Bluetooth status $status";
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(determineText(status)),
        ),
      );
}
