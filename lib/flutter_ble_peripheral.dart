
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterBlePeripheral {
  static const MethodChannel _channel =
      const MethodChannel('flutter_ble_peripheral');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
