/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothStatusCodes
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
import dev.steenbakker.flutter_ble_peripheral.callbacks.GattServerCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingCallback
import dev.steenbakker.flutter_ble_peripheral.callbacks.PeripheralAdvertisingSetCallback
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.SubscriptionChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.PeripheralStateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralBluetoothState
import dev.steenbakker.flutter_ble_peripheral.models.GattServiceRequest
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
    private val peripheralStateChangedHandler: PeripheralStateChangedHandler,
    private val dataReceivedHandler: DataReceivedHandler?,
    private val mtuChangedHandler: MtuChangedHandler?,
    private val subscriptionChangedHandler: SubscriptionChangedHandler?
) {

    companion object {
        /** Request code for Bluetooth enable intent. */
        const val REQUEST_ENABLE_BT = 4

        /** Request code for Bluetooth permission requests. */
        const val REQUEST_PERMISSION_BT = 8

        /** Tag for logging purposes. */
        private const val TAG = "FlutterBlePeripheralMgr"

        /** Client Characteristic Configuration Descriptor UUID for enabling notifications/indications. */
        private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    /** Bluetooth manager for accessing the BLE adapter. */
    var mBluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    /** BLE advertiser for broadcasting peripheral data. */
    var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = mBluetoothManager?.adapter?.bluetoothLeAdvertiser

    /** Callback invoked after permission request result */
    var permissionResultCallback: ((PeripheralBluetoothState) -> Unit)? = null

    /** Callback invoked after enable bluetooth request */
    var bluetoothEnabledCallback: ((Boolean) -> Unit)? = null

    /** GATT server instance for handling connections from centrals. */
    private var mBluetoothGattServer: BluetoothGattServer? = null

    /** Callback handler for GATT server events. */
    private var gattServerCallback: GattServerCallback? = null

    /**
     * Payloads waiting to go out per central.
     *
     * Android accepts one notification per central at a time and acknowledges it
     * with onNotificationSent; sending again before that drops the payload, so
     * back-to-back calls to [sendData] are queued instead.
     */
    private val notifyQueues = mutableMapOf<String, ArrayDeque<ByteArray>>()

    /** The centrals with a notification in flight, awaiting onNotificationSent. */
    private val notifyInFlight = mutableSetOf<String>()

    /** The last payload [sendData] was given, returned to a central that reads TX. */
    private var lastSentValue: ByteArray? = null

    /** TX characteristic for sending data to centrals (notify/indicate). */
    private var txCharacteristic: BluetoothGattCharacteristic? = null

    /** RX characteristic for receiving data from centrals (write). */
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

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
     * Optionally creates a GATT server with TX/RX characteristics for bidirectional communication.
     *
     * @param peripheralData The advertise data to broadcast
     * @param peripheralSettings The advertise settings (mode, power, timeout, etc.)
     * @param peripheralResponse Optional scan response data
     * @param mAdvertiseCallback Callback for advertising events
     * @param gattService Optional GATT service to serve alongside the advertisement
     */
    fun start(
        peripheralData: AdvertiseData,
        peripheralSettings: AdvertiseSettings,
        peripheralResponse: AdvertiseData?,
        mAdvertiseCallback: PeripheralAdvertisingCallback,
        gattService: GattServiceRequest? = null
    ) {
        mBluetoothLeAdvertiser!!.startAdvertising(
                peripheralSettings,
                peripheralData,
                peripheralResponse,
                mAdvertiseCallback
        )

        // Add GATT service if requested
        gattService?.let { addService(it) }
    }

    /**
     * Start BLE advertising using the Advertising Set API (Android O+).
     *
     * Supports extended advertising features like multiple PHYs and periodic advertising.
     * Optionally creates a GATT server with TX/RX characteristics for bidirectional communication.
     *
     * @param advertiseData The advertise data to broadcast
     * @param advertiseSettingsSet The advertising set parameters
     * @param peripheralResponse Optional scan response data
     * @param periodicResponse Optional periodic advertising data
     * @param periodicResponseSettings Optional periodic advertising parameters
     * @param maxExtendedAdvertisingEvents Maximum number of extended advertising events (0 = no limit)
     * @param duration Duration in 10ms units (0 = no time limit)
     * @param mAdvertiseSetCallback Callback for advertising set events
     * @param gattService Optional GATT service to serve alongside the advertisement
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
        mAdvertiseSetCallback: PeripheralAdvertisingSetCallback,
        gattService: GattServiceRequest? = null
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

        // Add GATT service if requested
        gattService?.let { addService(it) }
    }

    /**
     * Stop legacy BLE advertising and close GATT server.
     *
     * @param advertisingCallback The callback used when starting advertising
     */
    fun stop(advertisingCallback: AdvertiseCallback) {
        mBluetoothLeAdvertiser!!.stopAdvertising(advertisingCallback)
        closeGattServer()
    }

    /**
     * Stop advertising set (Android O+) and close GATT server.
     *
     * @param advertisingSetCallback The callback used when starting the advertising set
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun stopSet(advertisingSetCallback: AdvertisingSetCallback) {
        mBluetoothLeAdvertiser!!.stopAdvertisingSet(advertisingSetCallback)
        closeGattServer()
    }

    /**
     * Add the GATT service Dart asked for, with its TX and RX characteristics.
     *
     * @param request The service and characteristic uuids chosen by the caller
     */
    fun addService(request: GattServiceRequest) {
        val serviceUuid = request.serviceUuid
        val txUuid = request.txCharacteristicUuid
        val rxUuid = request.rxCharacteristicUuid
        try {
            // Create callback if not exists
            if (gattServerCallback == null) {
                gattServerCallback = GattServerCallback(
                    peripheralStateChangedHandler,
                    dataReceivedHandler,
                    mtuChangedHandler,
                    txUuid,
                    rxUuid
                )
                gattServerCallback!!.sendResponse = { device, requestId, status, offset, value ->
                    mBluetoothGattServer?.sendResponse(device, requestId, status, offset, value)
                }
                // A read gets the last value sendData pushed, so a central that
                // subscribes late can still pick it up.
                gattServerCallback!!.readCharacteristicValue = { uuid ->
                    if (uuid.equals(txUuid, ignoreCase = true)) lastSentValue else null
                }
                gattServerCallback!!.onNotificationSent = { device -> onNotificationSent(device) }
                gattServerCallback!!.onSubscriptionChanged = { subscribed ->
                    subscriptionChangedHandler?.publish(subscribed)
                }
            }

            // Open GATT server if not already open
            if (mBluetoothGattServer == null) {
                mBluetoothGattServer = mBluetoothManager?.openGattServer(context, gattServerCallback)
                Log.i(TAG, "GATT server opened")
            }

            // Create TX characteristic (for sending data to central)
            txCharacteristic = BluetoothGattCharacteristic(
                UUID.fromString(txUuid),
                BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                BluetoothGattCharacteristic.PROPERTY_INDICATE,
                BluetoothGattCharacteristic.PERMISSION_READ
            )

            // Add CCCD descriptor to TX characteristic for notifications
            val cccdDescriptor = BluetoothGattDescriptor(
                CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
            )
            txCharacteristic?.addDescriptor(cccdDescriptor)

            // Create RX characteristic (for receiving data from central)
            rxCharacteristic = BluetoothGattCharacteristic(
                UUID.fromString(rxUuid),
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )

            // Create service and add characteristics
            val service = BluetoothGattService(
                UUID.fromString(serviceUuid),
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )
            service.addCharacteristic(txCharacteristic)
            service.addCharacteristic(rxCharacteristic)

            // Add service to GATT server
            val added = mBluetoothGattServer?.addService(service)
            if (added == true) {
                Log.i(TAG, "GATT service added: $serviceUuid with TX: $txUuid, RX: $rxUuid")
            } else {
                Log.e(TAG, "Failed to add GATT service")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error adding GATT service: ${e.message}")
        }
    }

    /**
     * Send data to the subscribed centrals via the TX characteristic.
     *
     * The payload is queued per central rather than pushed straight out:
     * Android only accepts one notification per central at a time, and sending
     * again before onNotificationSent arrives silently drops it.
     *
     * @param data The data to send
     * @return true if the data was queued for at least one central
     */
    fun sendData(data: ByteArray): Boolean {
        val callback = gattServerCallback

        if (txCharacteristic == null || mBluetoothGattServer == null || callback == null) {
            Log.e(TAG, "Cannot send data: GATT server not initialized or no TX characteristic")
            return false
        }

        val devices = callback.getSubscribedDevices()
        if (devices.isEmpty()) {
            Log.w(TAG, "Cannot send data: no central is subscribed to the TX characteristic")
            return false
        }

        lastSentValue = data
        devices.forEach { device ->
            notifyQueues.getOrPut(device.address) { ArrayDeque() }.addLast(data)
            drainNotifyQueue(device)
        }
        Log.i(TAG, "Data queued for ${devices.size} device(s)")
        return true
    }

    /** Sends the next queued payload to [device], if it is not already busy. */
    private fun drainNotifyQueue(device: BluetoothDevice) {
        val characteristic = txCharacteristic ?: return
        val server = mBluetoothGattServer ?: return
        if (notifyInFlight.contains(device.address)) return

        val queue = notifyQueues[device.address] ?: return
        val next = queue.removeFirstOrNull() ?: return

        notifyInFlight.add(device.address)
        try {
            val sent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                server.notifyCharacteristicChanged(device, characteristic, false, next) == BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = next
                @Suppress("DEPRECATION")
                server.notifyCharacteristicChanged(device, characteristic, false)
            }
            if (!sent) {
                // Nothing will acknowledge a notification that was never sent.
                Log.w(TAG, "Notification to ${device.address} was rejected")
                notifyInFlight.remove(device.address)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending data: ${e.message}")
            notifyInFlight.remove(device.address)
        }
    }

    /** Called once a central has acknowledged a notification. */
    private fun onNotificationSent(device: BluetoothDevice) {
        notifyInFlight.remove(device.address)
        drainNotifyQueue(device)
    }

    /**
     * Close the GATT server and clean up resources.
     */
    fun closeGattServer() {
        try {
            mBluetoothGattServer?.clearServices()
            mBluetoothGattServer?.close()
            mBluetoothGattServer = null
            gattServerCallback = null
            txCharacteristic = null
            rxCharacteristic = null
            notifyQueues.clear()
            notifyInFlight.clear()
            lastSentValue = null
            Log.i(TAG, "GATT server closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing GATT server: ${e.message}")
        }
    }

    /**
     * Check if GATT server is running.
     */
    fun isGattServerRunning(): Boolean {
        return mBluetoothGattServer != null
    }

    /**
     * Whether any central holds a connection to the GATT server.
     *
     * A connected central is not necessarily one that can be notified; see
     * [hasSubscribedDevices].
     */
    fun hasConnectedDevices(): Boolean {
        return gattServerCallback?.hasConnectedDevices() ?: false
    }

    /**
     * Whether any central subscribed to the TX characteristic, which is the
     * state in which [sendData] can deliver.
     */
    fun hasSubscribedDevices(): Boolean {
        return gattServerCallback?.hasSubscribedDevices() ?: false
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
