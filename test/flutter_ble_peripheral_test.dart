import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_ble_peripheral');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await FlutterBlePeripheral.platformVersion, '42');
  });
}
