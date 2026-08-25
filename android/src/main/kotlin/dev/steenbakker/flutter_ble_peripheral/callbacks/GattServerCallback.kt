/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothProfile
import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.PeripheralStateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import java.io.ByteArrayOutputStream

/**
 * Bridges the GATT server between Android and Flutter.
 *
 * Two sets of devices are tracked, because they answer different questions:
 * [getConnectedDevices] is every central with a link to this peripheral, while
 * [getSubscribedDevices] is the subset that wrote the CCCD to ask for
 * notifications. Only the latter can be notified, so it is what `sendData`
 * checks.
 */
class GattServerCallback(
    private val peripheralStateChangedHandler: PeripheralStateChangedHandler,
    private val dataReceivedHandler: DataReceivedHandler?,
    private val mtuChangedHandler: MtuChangedHandler?,
    private val txCharacteristicUuid: String,
    private val rxCharacteristicUuid: String
) : BluetoothGattServerCallback() {

    private companion object {
        /** Client Characteristic Configuration Descriptor. */
        const val CCCD_UUID = "00002902-0000-1000-8000-00805f9b34fb"
    }

    private val tag = "GattServerCallback"
    private val connectedDevices = mutableSetOf<BluetoothDevice>()
    private val subscribedDevices = mutableSetOf<BluetoothDevice>()

    /**
     * Long writes arrive as a series of prepared chunks that only take effect on
     * execute, keyed here by device address and characteristic uuid.
     */
    private val preparedWrites = mutableMapOf<Pair<String, String>, ByteArrayOutputStream>()

    /** Sends a response to a central. Set by the manager that owns the server. */
    var sendResponse: (device: BluetoothDevice?, requestId: Int, status: Int, offset: Int, value: ByteArray?) -> Unit =
            { _, _, _, _, _ -> }

    /** The current value of a characteristic, used to answer read requests. */
    var readCharacteristicValue: (uuid: String) -> ByteArray? = { null }

    /** Called when a notification has been acknowledged, so the next may be sent. */
    var onNotificationSent: (device: BluetoothDevice) -> Unit = { }

    /** Called whenever the set of subscribed centrals becomes empty or non-empty. */
    var onSubscriptionChanged: (subscribed: Boolean) -> Unit = { }

    override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
        super.onConnectionStateChange(device, status, newState)

        Log.i(tag, "onConnectionStateChange: device=${device?.address}, status=$status, newState=$newState")

        if (device == null) {
            Log.w(tag, "onConnectionStateChange called with null device")
            return
        }

        if (status != BluetoothGatt.GATT_SUCCESS) {
            Log.w(tag, "onConnectionStateChange with non-success status: $status for device ${device.address}")
            return
        }

        when (newState) {
            BluetoothProfile.STATE_CONNECTED -> {
                Log.i(tag, "Device connected: ${device.address}")
                connectedDevices.add(device)
                peripheralStateChangedHandler.publish(PeripheralState.connected)
            }
            BluetoothProfile.STATE_DISCONNECTED -> {
                Log.i(tag, "Device disconnected: ${device.address}")
                connectedDevices.remove(device)
                // A disconnected central cannot still be subscribed, and its
                // half-finished long writes are gone with it.
                if (subscribedDevices.remove(device)) {
                    onSubscriptionChanged(subscribedDevices.isNotEmpty())
                }
                preparedWrites.keys.filter { it.first == device.address }
                        .forEach { preparedWrites.remove(it) }
                if (connectedDevices.isEmpty()) {
                    peripheralStateChangedHandler.publish(PeripheralState.advertising)
                }
            }
            BluetoothProfile.STATE_CONNECTING -> Log.i(tag, "Device connecting: ${device.address}")
            BluetoothProfile.STATE_DISCONNECTING -> Log.i(tag, "Device disconnecting: ${device.address}")
            else -> Log.w(tag, "Unknown connection state: $newState for device ${device.address}")
        }
    }

    override fun onCharacteristicReadRequest(
        device: BluetoothDevice?,
        requestId: Int,
        offset: Int,
        characteristic: BluetoothGattCharacteristic?
    ) {
        super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
        Log.i(tag, "Read request from ${device?.address} for characteristic ${characteristic?.uuid}")

        val uuid = characteristic?.uuid?.toString()
        if (uuid == null) {
            sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
            return
        }

        val value = readCharacteristicValue(uuid) ?: ByteArray(0)
        // A central reading a value longer than the MTU comes back for the rest
        // with a growing offset, so only the tail is returned each time.
        if (offset > value.size) {
            sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null)
            return
        }
        sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value.copyOfRange(offset, value.size))
    }

    override fun onCharacteristicWriteRequest(
        device: BluetoothDevice?,
        requestId: Int,
        characteristic: BluetoothGattCharacteristic?,
        preparedWrite: Boolean,
        responseNeeded: Boolean,
        offset: Int,
        value: ByteArray?
    ) {
        super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)

        Log.i(tag, "Write request from ${device?.address} for characteristic ${characteristic?.uuid}")

        val uuid = characteristic?.uuid?.toString()
        if (device == null || uuid == null || !uuid.equals(rxCharacteristicUuid, ignoreCase = true)) {
            Log.w(tag, "Write to unsupported characteristic: $uuid")
            if (responseNeeded) {
                sendResponse(device, requestId, BluetoothGatt.GATT_WRITE_NOT_PERMITTED, offset, null)
            }
            return
        }

        if (preparedWrite) {
            // Hold the chunk until the central executes the write.
            val buffer = preparedWrites.getOrPut(device.address to uuid) { ByteArrayOutputStream() }
            if (offset != buffer.size()) {
                Log.w(tag, "Prepared write out of order: offset $offset, have ${buffer.size()}")
                preparedWrites.remove(device.address to uuid)
                if (responseNeeded) {
                    sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null)
                }
                return
            }
            value?.let { buffer.write(it) }
            // The prepare write response has to echo back what was queued.
            if (responseNeeded) {
                sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
            return
        }

        publishReceived(value)
        if (responseNeeded) {
            sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
        }
    }

    override fun onDescriptorReadRequest(
        device: BluetoothDevice?,
        requestId: Int,
        offset: Int,
        descriptor: BluetoothGattDescriptor?
    ) {
        super.onDescriptorReadRequest(device, requestId, offset, descriptor)
        Log.i(tag, "Descriptor read request from ${device?.address} for descriptor ${descriptor?.uuid}")

        // Report whether this central is subscribed, rather than the descriptor's
        // shared value, which is the same object for every central.
        val isCccd = descriptor?.uuid?.toString().equals(CCCD_UUID, ignoreCase = true)
        val value = if (isCccd && device != null && subscribedDevices.contains(device)) {
            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        } else if (isCccd) {
            BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
        } else {
            @Suppress("DEPRECATION")
            descriptor?.value
        }

        sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
    }

    override fun onDescriptorWriteRequest(
        device: BluetoothDevice?,
        requestId: Int,
        descriptor: BluetoothGattDescriptor?,
        preparedWrite: Boolean,
        responseNeeded: Boolean,
        offset: Int,
        value: ByteArray?
    ) {
        super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
        Log.i(tag, "Descriptor write request from ${device?.address} for descriptor ${descriptor?.uuid}")

        val isCccd = descriptor?.uuid?.toString().equals(CCCD_UUID, ignoreCase = true)
        val isTx = descriptor?.characteristic?.uuid?.toString()
                .equals(txCharacteristicUuid, ignoreCase = true)

        if (isCccd && isTx && device != null && value != null && value.isNotEmpty()) {
            // Bit 0 is notify, bit 1 is indicate. Either means this central
            // wants what sendData sends.
            val wants = value[0].toInt() and 0x03 != 0
            val changed = if (wants) subscribedDevices.add(device) else subscribedDevices.remove(device)
            Log.i(tag, "${device.address} ${if (wants) "subscribed to" else "unsubscribed from"} $txCharacteristicUuid")
            if (changed) {
                onSubscriptionChanged(subscribedDevices.isNotEmpty())
            }
        }

        if (responseNeeded) {
            sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
        }
    }

    override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
        super.onMtuChanged(device, mtu)
        Log.i(tag, "MTU changed to $mtu for device ${device?.address}")

        Handler(Looper.getMainLooper()).post {
            mtuChangedHandler?.publish(mtu)
        }
    }

    override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
        super.onNotificationSent(device, status)
        if (status != BluetoothGatt.GATT_SUCCESS) {
            Log.w(tag, "Notification to ${device?.address} failed with status $status")
        }
        device?.let { onNotificationSent(it) }
    }

    override fun onExecuteWrite(device: BluetoothDevice?, requestId: Int, execute: Boolean) {
        super.onExecuteWrite(device, requestId, execute)
        Log.i(tag, "Execute write from ${device?.address}, execute: $execute")

        val address = device?.address
        if (address != null) {
            val keys = preparedWrites.keys.filter { it.first == address }
            for (key in keys) {
                val buffer = preparedWrites.remove(key) ?: continue
                if (execute) {
                    publishReceived(buffer.toByteArray())
                }
            }
        }

        sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
    }

    /** Forwards what a central wrote to the RX characteristic to Flutter. */
    private fun publishReceived(data: ByteArray?) {
        if (data == null || data.isEmpty()) return
        Log.i(tag, "Received data: ${data.size} bytes")
        Handler(Looper.getMainLooper()).post {
            dataReceivedHandler?.publish(data)
        }
    }

    fun getConnectedDevices(): Set<BluetoothDevice> = connectedDevices.toSet()

    fun hasConnectedDevices(): Boolean = connectedDevices.isNotEmpty()

    /** The centrals that asked to be notified, which is who `sendData` reaches. */
    fun getSubscribedDevices(): Set<BluetoothDevice> = subscribedDevices.toSet()

    fun hasSubscribedDevices(): Boolean = subscribedDevices.isNotEmpty()
}
