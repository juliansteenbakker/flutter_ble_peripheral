import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/src/flutter_ble_peripheral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const methodChannel =
      MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');

  TestWidgetsFlutterBinding.ensureInitialized();
  late FlutterBlePeripheral blePeripheral;

  setUp(() {
    blePeripheral = FlutterBlePeripheral();
    methodChannel.setMockMethodCallHandler((methodCall) async {
      if (methodCall.method == 'start' || methodCall.method == 'stop') {
        return null;
      } else if (methodCall.method == 'isAdvertising') {
        return Future<bool>.value(true);
      }
      return null;
    });
  });

  tearDown(() {
    methodChannel.setMockMethodCallHandler(null);
  });

  test('checking if is advertising returns true', () async {
    expect(await blePeripheral.isAdvertising(), isTrue);
  });
}
