import 'constants.dart';

/// Connection is an enum of supported network states
enum PeripheralState { idle, advertising, connected, unsupported, unauthorized }

PeripheralState intToPeripheralState(int peripheralStateInt) {
  var peripheralState = PeripheralState.idle;
  switch (peripheralStateInt) {
    case Constants.peripheralStateAdvertising:
      peripheralState = PeripheralState.advertising;
      break;
    case Constants.peripheralStateConnected:
      peripheralState = PeripheralState.connected;
      break;
    case Constants.peripheralStateIdle:
      peripheralState = PeripheralState.idle;
      break;
    case Constants.peripheralStateUnauthorized:
      peripheralState = PeripheralState.unauthorized;
      break;
    case Constants.peripheralStateUnsupported:
      peripheralState = PeripheralState.unsupported;
      break;
  }
  return peripheralState;
}
