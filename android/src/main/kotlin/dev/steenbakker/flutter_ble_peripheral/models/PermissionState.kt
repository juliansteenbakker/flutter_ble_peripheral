package dev.steenbakker.flutter_ble_peripheral.models

enum class PermissionState(val nr: Int) {
    /// Status is not (yet) determined.
    Granted(0),

    /// BLE is not supported on this device.
    Denied(1),

    /// BLE usage is not authorized for this app.
    PermanentlyDenied(2),
}