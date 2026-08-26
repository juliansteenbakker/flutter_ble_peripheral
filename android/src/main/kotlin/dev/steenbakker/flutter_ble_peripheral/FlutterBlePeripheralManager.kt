/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.PeriodicAdvertisingParameters
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.edit
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.handlers.PeripheralStateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralBluetoothState
import io.flutter.Log
import java.util.UUID

/**
 * BLE Peripheral manager responsible for low-level Bluetooth LE peripheral operations.
 *
 * Responsibilities:
 * - Manage BLE advertising (both legacy and advertising sets).
 * - Handle Bluetooth adapter state and permissions.
 * - Manage GATT server for bidirectional communication with centrals.
 * - Coordinate with Flutter handlers for state changes, data received, and MTU changes.
 */
class FlutterBlePeripheralManager(
    private val context: Context,
    private val peripheralStateChangedHandler: PeripheralStateChangedHandler
) {

    companion object {
        /** Request code for Bluetooth enable intent. */
        const val REQUEST_ENABLE_BT = 4

        /** Request code for Bluetooth permission requests. */
        const val REQUEST_PERMISSION_BT = 8

        /** Tag for logging purposes. */
        private const val TAG = "FlutterBlePeripheralMgr"
    }

    /** Bluetooth manager for accessing the BLE adapter. */
    var mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    /** BLE advertiser for broadcasting peripheral data. */
    var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = mBluetoothManager?.adapter?.bluetoothLeAdvertiser

    /** Callback invoked after permission request result */
    var permissionResultCallback: ((PeripheralBluetoothState) -> Unit)? = null

    /** Callback invoked after enable bluetooth request */
    var bluetoothEnabledCallback: ((Boolean) -> Unit)? = null

    // Permissions for Bluetooth API > 31
    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothAdvertisePermission(context: Context): Boolean {
        return (context.checkSelfPermission(
            Manifest.permission.BLUETOOTH_ADVERTISE
        )
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasBluetoothConnectPermission(context: Context): Boolean {
        return (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun hasLocationFinePermission(context: Context): Boolean {
        return (context.checkSelfPermission(
            Manifest.permission.ACCESS_FINE_LOCATION
        )
                == PackageManager.PERMISSION_GRANTED)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun hasLocationCoarsePermission(context: Context): Boolean {
        return (context.checkSelfPermission(
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
                == PackageManager.PERMISSION_GRANTED)
    }

    /**
     * Start BLE advertising using the legacy advertising API.
     *
     * @param peripheralData The advertise data to broadcast
     * @param peripheralSettings The advertise settings (mode, power, timeout, etc.)
     * @param peripheralResponse Optional scan response data
     * @param mAdvertiseCallback Callback for advertising events
     */
    fun start(
        peripheralData: AdvertiseData,
        peripheralSettings: AdvertiseSettings,
        peripheralResponse: AdvertiseData?,
        mAdvertiseCallback: PeripheralAdvertisingCallback
    ) {
        mBluetoothLeAdvertiser!!.startAdvertising(
                peripheralSettings,
                peripheralData,
                peripheralResponse,
                mAdvertiseCallback
        )
    }

    /**
     * Start BLE advertising using the Advertising Set API (Android O+).
     *
     * Supports extended advertising features like multiple PHYs and periodic advertising.
     * @param advertiseData The advertise data to broadcast
     * @param advertiseSettingsSet The advertising set parameters
     * @param peripheralResponse Optional scan response data
     * @param periodicResponse Optional periodic advertising data
     * @param periodicResponseSettings Optional periodic advertising parameters
     * @param maxExtendedAdvertisingEvents Maximum number of extended advertising events (0 = no limit)
     * @param duration Duration in 10ms units (0 = no time limit)
     * @param mAdvertiseSetCallback Callback for advertising set events
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(
        advertiseData: AdvertiseData,
        advertiseSettingsSet: AdvertisingSetParameters,
        peripheralResponse: AdvertiseData?,
        periodicResponse: AdvertiseData?,
        periodicResponseSettings: PeriodicAdvertisingParameters?,
        maxExtendedAdvertisingEvents: Int = 0,
        duration: Int = 0,
        mAdvertiseSetCallback: PeripheralAdvertisingSetCallback
    ) {
        mBluetoothLeAdvertiser!!.startAdvertisingSet(
                advertiseSettingsSet,
                advertiseData,
                peripheralResponse,
                periodicResponseSettings,
                periodicResponse,
                duration,
                maxExtendedAdvertisingEvents,
                mAdvertiseSetCallback,
        )
    }

    /**
     * Stop legacy BLE advertising.
     *
     * @param advertisingCallback The callback used when starting advertising
     */
    fun stop(advertisingCallback: AdvertiseCallback) {
        mBluetoothLeAdvertiser!!.stopAdvertising(advertisingCallback)
    }

    /**
     * Stop advertising set (Android O+).
     *
     * @param advertisingSetCallback The callback used when starting the advertising set
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun stopSet(advertisingSetCallback: AdvertisingSetCallback) {
        mBluetoothLeAdvertiser!!.stopAdvertisingSet(advertisingSetCallback)
    }

    /**
     * Checks whether Bluetooth is currently enabled.
     *
     * @return `true` if enabled, `false` otherwise
     */
    fun isBluetoothEnabled(): Boolean {
        return mBluetoothManager?.adapter?.isEnabled ?: false
    }

    /**
     * Checks whether the required permissions are granted, without a rationale check.
     *
     * Unlike [getMissingPermissions] this only needs a [Context], so it can be used
     * outside of an activity, for example when observing the adapter state.
     */
    fun hasRequiredPermissions(context: Context): Boolean {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
                hasBluetoothAdvertisePermission(context) && hasBluetoothConnectPermission(context)

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ->
                hasLocationCoarsePermission(context) && hasLocationFinePermission(context)

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                hasLocationCoarsePermission(context)

            else -> true
        }
    }

    /**
     * Attempts to enable Bluetooth on the device.
     *
     * If [callback] is not null, shows the system dialog to request user approval.
     * If [callback] is null and the Android version is below Tiramisu, enables Bluetooth programmatically.
     *
     * @param activity Activity to use for launching the enable dialog
     * @param callback Response on intent to enable bluetooth (pre-Android 13)
     */
    fun enableBluetooth(activity: Activity, callback: ((Boolean) -> Unit)?) {
        if (callback != null) {
            bluetoothEnabledCallback = callback
            ActivityCompat.startActivityForResult(
                activity,
                Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                REQUEST_ENABLE_BT,
                null
            )
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            @Suppress("DEPRECATION")
            mBluetoothManager!!.adapter.enable()
        }
    }

    /**
     * Returns a list of missing permissions depending on the Android version.
     *
     * @param activity The activity to check permissions against
     * @return List of permission strings that are not currently granted
     */
    fun getMissingPermissions(activity: Activity): List<String> {
        val missingPermissions = mutableListOf<String>()

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                if (!hasBluetoothAdvertisePermission(activity)) {
                    missingPermissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
                }
                if (!hasBluetoothConnectPermission(activity)) {
                    missingPermissions.add(Manifest.permission.BLUETOOTH_CONNECT)
                }
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> {
                if (!hasLocationFinePermission(activity)) {
                    missingPermissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
                }
                if (!hasLocationCoarsePermission(activity)) {
                    missingPermissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
                }
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                if (!hasLocationCoarsePermission(activity)) {
                    missingPermissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
                }
            }
        }

        return missingPermissions
    }

    /**
     * Checks and optionally requests missing Bluetooth-related permissions.
     *
     * @param activity The activity to request permissions from
     * @param callback Optional callback for async permission result.
     * If `null`, the method just returns the current [PeripheralBluetoothState].
     *
     * @return Current [PeripheralBluetoothState] if no request is needed, or `null` if a request was initiated.
     */
    fun requestPermission(activity: Activity, callback: ((PeripheralBluetoothState) -> Unit)?): PeripheralBluetoothState? {
        val missingPermissions = getMissingPermissions(activity)

        // No missing permissions
        if (missingPermissions.isEmpty()) {
            setPermissionGranted(activity, true)
            return PeripheralBluetoothState.Granted
        }

        val previouslyRequested = getPermissionRequested(activity)
        val previouslyGranted = getPermissionGranted(activity)

        val shouldShowRationale = missingPermissions.any { permission ->
            ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        }

        val isRevoked = previouslyGranted && missingPermissions.isNotEmpty()

        // Just checking status
        if (callback == null) {
            return when {
                isRevoked -> PeripheralBluetoothState.Denied
                shouldShowRationale -> PeripheralBluetoothState.Denied
                !previouslyRequested -> PeripheralBluetoothState.Denied
                else -> PeripheralBluetoothState.PermanentlyDenied
            }
        }

        // Request permission
        permissionResultCallback = callback
        setPermissionRequested(activity, true)
        ActivityCompat.requestPermissions(
            activity,
            missingPermissions.toTypedArray(),
            REQUEST_PERMISSION_BT
        )

        return null
    }

    /**
     * Returns the current Bluetooth adapter state as a [PeripheralBluetoothState] enum.
     *
     * @return [PeripheralBluetoothState.Unsupported] if adapter is null,
     * [PeripheralBluetoothState.Denied] if disabled, [PeripheralBluetoothState.Ready] if enabled.
     */
    fun getBluetoothState(): PeripheralBluetoothState {
        val adapter = mBluetoothManager?.adapter
        return if (adapter == null) PeripheralBluetoothState.Unsupported
        else if (!adapter.isEnabled) PeripheralBluetoothState.Denied
        else PeripheralBluetoothState.Ready
    }

    /**
     * Ensures Bluetooth is ready before performing BLE operations.
     *
     * - Checks adapter support
     * - Requests permissions if needed
     * - Enables Bluetooth if disabled
     *
     * @param activity The activity context
     * @param onReady Callback executed if Bluetooth is ready
     * @param onError Callback executed with the error [PeripheralBluetoothState]
     */
    fun ensureBluetoothReady(
        activity: Activity,
        onReady: () -> Unit,
        onError: (PeripheralBluetoothState) -> Unit
    ) {
        if (getBluetoothState() == PeripheralBluetoothState.Unsupported) {
            onError(PeripheralBluetoothState.Unsupported)
            return
        }

        val permissionState = requestPermission(activity) { permState ->
            if (permState == PeripheralBluetoothState.Granted) {
                if (!isBluetoothEnabled()) {
                    enableBluetooth(activity) { bluetoothEnabled ->
                        if (bluetoothEnabled) {
                            onReady()
                        } else {
                            onError(PeripheralBluetoothState.TurnedOff)
                        }
                    }
                } else {
                    onReady()
                }
            } else {
                onError(permState)
            }
        }

        if (permissionState == PeripheralBluetoothState.Granted) {
            if (!isBluetoothEnabled()) {
                enableBluetooth(activity) { bluetoothEnabled ->
                    if (bluetoothEnabled) {
                        onReady()
                    } else {
                        onError(PeripheralBluetoothState.TurnedOff)
                    }
                }
            } else {
                onReady()
            }
        }
    }

    /**
     * Persist the permission granted flag in SharedPreferences.
     */
    fun setPermissionGranted(context: Context, granted: Boolean) {
        val prefs = context.getSharedPreferences("flutter_ble_central", Context.MODE_PRIVATE)
        prefs.edit { putBoolean("permission_granted", granted) }
    }

    /**
     * Persist the permission requested flag in SharedPreferences.
     */
    fun setPermissionRequested(context: Context, granted: Boolean) {
        val prefs = context.getSharedPreferences("flutter_ble_central", Context.MODE_PRIVATE)
        prefs.edit { putBoolean("permission_requested", granted) }
    }

    /**
     * Returns whether permission has been granted previously.
     */
    fun getPermissionGranted(context: Context): Boolean {
        val prefs = context.getSharedPreferences("flutter_ble_central", Context.MODE_PRIVATE)
        return prefs.getBoolean("permission_granted", false)
    }

    /**
     * Returns whether permission has been requested previously.
     */
    fun getPermissionRequested(context: Context): Boolean {
        val prefs = context.getSharedPreferences("flutter_ble_central", Context.MODE_PRIVATE)
        return prefs.getBoolean("permission_requested", false)
    }
}
