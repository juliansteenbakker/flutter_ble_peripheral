import 'package:flutter_ble_peripheral/src/models/peripheral_state.dart';

class InvalidState implements Exception {
  final PeripheralState state;
  final String msg;

  InvalidState(this.state, String? msg) :
      msg = msg ?? "This operation forbids the current state ${state.name}"
  ;

  @override
  String toString() => 'InvalidState: $msg';
}
