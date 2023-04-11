package dev.steenbakker.flutter_ble_peripheral.models

enum class PermissionState {
    /// Status is not (yet) determined.
    Granted,

    /// BLE is not supported on this device.
    ShouldShowRequestPermissionRationale,

    /// BLE usage is not authorized for this app.
    PermanentlyDenied,
}