package dev.steenbakker.flutter_ble_peripheral.models

enum class PeripheralState(val value: Int) {
    /// Status is not (yet) determined.
    unknown(10),

    /// BLE is not supported on this device.
    unsupported(11),

    /// BLE usage is not authorized for this app.
    unauthorized(12),

    /// BLE is turned off.
    poweredOff(13),

    /// BLE is fully operating for this app.
    idle(14),

    /// BLE is advertising data.
    advertising(15),

    /// BLE is connected to a device.
    connected(16),
}