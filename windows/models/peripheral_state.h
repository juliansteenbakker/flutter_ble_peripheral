#ifndef FLUTTER_PLUGIN_PERIPHERAL_STATE_H_
#define FLUTTER_PLUGIN_PERIPHERAL_STATE_H_

namespace flutter_ble_peripheral {
namespace models {

    // Mirrors the Dart `PeripheralState`, which is what the state change stream
    // carries. The value is that enum's index, so keep the order in sync.
    enum class PeripheralState {
        Unknown = 0,
        Unsupported = 1,
        Unauthorized = 2,
        PoweredOff = 3,
        Idle = 4,
        Advertising = 5,
        Connected = 6,
        ShouldShowRequestPermissionRationale = 7,
    };

    // Mirrors the Dart `BluetoothPeripheralState`, which is what `start`, `stop`
    // and the permission methods return. The value is that enum's index, so keep
    // the order in sync.
    enum class BluetoothPeripheralState {
        Granted = 0,
        Denied = 1,
        PermanentlyDenied = 2,
        Restricted = 3,
        Limited = 4,
        TurnedOff = 5,
        Unsupported = 6,
        Unknown = 7,
        Ready = 8,
    };

}  // namespace models
}  // namespace flutter_ble_peripheral

#endif  // FLUTTER_PLUGIN_PERIPHERAL_STATE_H_
