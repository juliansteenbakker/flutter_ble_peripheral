package dev.steenbakker.flutter_ble_peripheral.models

/**
 * Represents the various states related to Bluetooth permissions,
 * Bluetooth adapter status, or platform restrictions.
 *
 * This enum is used to communicate permission and adapter state information
 * between the Android native layer and Flutter.
 *
 * Some states are platform-specific (e.g., iOS-only values are retained
 * for API compatibility across platforms).
 *
 * @property value The integer value used when serializing state to Flutter.
 */
enum class PeripheralBluetoothState(val value: Int) {

    /**
     * The user granted access to the requested feature.
     * (e.g., Bluetooth permission granted and adapter is enabled).
     */
    Granted(1),

    /**
     * The user denied access to the requested feature.
     * The app can still request the permission again.
     */
    Denied(2),

    /**
     * Permission to the requested feature is permanently denied.
     *
     * The permission dialog will **not** be shown when requesting this permission.
     * The user may still change the permission status in system settings.
     */
    PermanentlyDenied(3),

    /**
     * The user cannot change this app's permission status,
     * possibly due to active restrictions such as parental controls being in place.
     *
     * ⚠️ Only supported on **iOS**.
     */
    Restricted(4),

    /**
     * The user has authorized this application for **limited access**.
     *
     * ⚠️ Only supported on **iOS 14+**.
     */
    Limited(5),

    /**
     * Bluetooth is turned off.
     * Permissions may be granted, but the adapter is disabled.
     */
    TurnedOff(6),

    /**
     * The device does not support Bluetooth or the required feature.
     */
    Unsupported(7),

    /**
     * The status is unknown.
     *
     * Typically returned when the permission state cannot be determined.
     */
    Unknown(8),

    /**
     * Bluetooth is fully available and ready to use.
     * This indicates that permissions are granted and the adapter is enabled.
     */
    Ready(9),
}
