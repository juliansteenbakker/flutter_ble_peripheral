package dev.steenbakker.flutter_ble_peripheral.models

/**
 * Represents the various states of the Flutter BLE Peripheral.
 */
enum class PeripheralState {

    /**
     * The current BLE status is not yet determined.
     */
    unknown,

    /**
     * BLE is not supported on this device.
     */
    unsupported,

    /**
     * The app is not authorized to use BLE.
     */
    unauthorized,

    /**
     * Bluetooth is currently turned off.
     */
    poweredOff,

    /**
     * Android only: Location services are disabled, which may affect BLE functionality.
     */
    locationServicesDisabled,

    /**
     * BLE is available and ready to use, but not currently advertising or connected.
     */
    idle,

    /**
     * BLE is actively advertising data.
     */
    advertising,

    /**
     * BLE is connected to a remote device.
     */
    connected
}
