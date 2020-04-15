import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_peripheral/main.dart';

void main() {
  const MethodChannel methodChannel = MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterBlePeripheral blePeripheral;

  setUp(() {
    blePeripheral = FlutterBlePeripheral();
    methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'start' || methodCall.method == 'stop') {
        return Future<void>.value();
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
