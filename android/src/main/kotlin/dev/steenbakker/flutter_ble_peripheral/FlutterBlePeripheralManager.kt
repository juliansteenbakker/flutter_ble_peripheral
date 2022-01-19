/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import androidx.annotation.RequiresApi
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralData
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*


class FlutterBlePeripheralManager {

    private val tag: String = "BLE Peripheral"
    private lateinit var mBluetoothManager: BluetoothManager
    private lateinit var mBluetoothGattServer: BluetoothGattServer
    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var mBluetoothGatt: BluetoothGatt? = null
    private var mBluetoothDevice: BluetoothDevice? = null

    private lateinit var context: Context

    private var isAdvertising = false

    var onMtuChanged: ((Int) -> Unit)? = null
    var onStateChanged: ((PeripheralState) -> Unit)? = null
    var onDataReceived: ((ByteArray) -> Unit)? = null

    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    fun init(context: Context) {
        this.context = context

        val bluetoothManager: BluetoothManager? =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

        if (bluetoothManager == null) {
            throw PeripheralException(PeripheralState.unsupported)
        } else {
            mBluetoothManager = bluetoothManager

            val bluetoothAdapter: BluetoothAdapter = bluetoothManager.adapter
            if (bluetoothAdapter.bluetoothLeAdvertiser == null) {
                throw PeripheralException(PeripheralState.poweredOff)
            } else {
                mBluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
            }
        }
    }

    fun handlePeripheralException(e: PeripheralException, result: MethodChannel.Result?) {
        when (e.state) {
            PeripheralState.unsupported -> {
                onStateChanged?.invoke(PeripheralState.unsupported)
                Log.e(tag, "This device does not support bluetooth LE")
                result?.error("Not Supported", "This device does not support bluetooth LE", e.state.name)
            }
            PeripheralState.poweredOff -> {
                onStateChanged?.invoke(PeripheralState.poweredOff)
                Log.e(tag, "Bluetooth may be turned off or is not supported")
                result?.error("Not powered", "Bluetooth may be turned off or is not supported", e.state.name)
            }
            else -> {
                onStateChanged?.invoke(e.state)
                Log.e(tag, e.state.name)
                result?.error(e.state.name, null, null)
            }
        }
    }

    private val mAdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
            isAdvertising = true
            onStateChanged?.invoke(PeripheralState.advertising)
        }

        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            val statusText: String
            when (errorCode) {
                ADVERTISE_FAILED_ALREADY_STARTED -> {
                    statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                    isAdvertising = true
                    onStateChanged?.invoke(PeripheralState.advertising)
                }
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                    statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    isAdvertising = false
                    onStateChanged?.invoke(PeripheralState.unsupported)
                }
                ADVERTISE_FAILED_INTERNAL_ERROR -> {
                    statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                    isAdvertising = false
                    onStateChanged?.invoke(PeripheralState.idle)
                }
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                    statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    isAdvertising = false
                    onStateChanged?.invoke(PeripheralState.idle)
                }
                ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                    statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    isAdvertising = false
                    onStateChanged?.invoke(PeripheralState.idle)
                }
                else -> {
                    statusText = "UNDOCUMENTED"
                    onStateChanged?.invoke(PeripheralState.unknown)
                }
            }

            Log.e(tag, "ERROR while starting advertising: $errorCode - $statusText")
            isAdvertising = false
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private val mAdvertiseSetCallback = object : AdvertisingSetCallback() {

        /**
         * Callback triggered in response to {@link BluetoothLeAdvertiser#startAdvertisingSet}
         * indicating result of the operation. If status is ADVERTISE_SUCCESS, then advertisingSet
         * contains the started set and it is advertising. If error occurred, advertisingSet is
         * null, and status will be set to proper error code.
         *
         * @param advertisingSet The advertising set that was started or null if error.
         * @param txPower tx power that will be used for this set.
         * @param status Status of the operation.
         */

        override fun onAdvertisingSetStarted(
            advertisingSet: AdvertisingSet?,
            txPower: Int,
            status: Int
        ) {
        }

        /**
         * Callback triggered in response to [BluetoothLeAdvertiser.stopAdvertisingSet]
         * indicating advertising set is stopped.
         *
         * @param advertisingSet The advertising set.
         */
        override fun onAdvertisingSetStopped(advertisingSet: AdvertisingSet?) {}

        /**
         * Callback triggered in response to [BluetoothLeAdvertiser.startAdvertisingSet]
         * indicating result of the operation. If status is ADVERTISE_SUCCESS, then advertising set is
         * advertising.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onAdvertisingEnabled(
            advertisingSet: AdvertisingSet?,
            enable: Boolean,
            status: Int
        ) {
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setAdvertisingData] indicating
         * result of the operation. If status is ADVERTISE_SUCCESS, then data was changed.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onAdvertisingDataSet(advertisingSet: AdvertisingSet?, status: Int) {}

        /**
         * Callback triggered in response to [AdvertisingSet.setAdvertisingData] indicating
         * result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onScanResponseDataSet(advertisingSet: AdvertisingSet?, status: Int) {}

        /**
         * Callback triggered in response to [AdvertisingSet.setAdvertisingParameters]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param txPower tx power that will be used for this set.
         * @param status Status of the operation.
         */
        override fun onAdvertisingParametersUpdated(
            advertisingSet: AdvertisingSet?,
            txPower: Int, status: Int
        ) {
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setPeriodicAdvertisingParameters]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onPeriodicAdvertisingParametersUpdated(
            advertisingSet: AdvertisingSet?,
            status: Int
        ) {
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setPeriodicAdvertisingData]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onPeriodicAdvertisingDataSet(
            advertisingSet: AdvertisingSet?,
            status: Int
        ) {
        }

        /**
         * Callback triggered in response to [AdvertisingSet.setPeriodicAdvertisingEnabled]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param status Status of the operation.
         */
        override fun onPeriodicAdvertisingEnabled(
            advertisingSet: AdvertisingSet?, enable: Boolean,
            status: Int
        ) {
        }

        /**
         * Callback triggered in response to [AdvertisingSet.getOwnAddress]
         * indicating result of the operation.
         *
         * @param advertisingSet The advertising set.
         * @param addressType type of address.
         * @param address advertising set bluetooth address.
         * @hide
         */
//        override fun onOwnAddressRead(advertisingSet: AdvertisingSet?, addressType: Int, address: String?) {}
    }

    fun start(peripheralData: PeripheralData, result: MethodChannel.Result, peripheralResponse: PeripheralData?) {
        try {
            init(context)
        } catch (e: PeripheralException) {
            handlePeripheralException(e, result)
            return
        }

        val advertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode(peripheralData.advertiseMode)
            .setConnectable(peripheralData.connectable)
            .setTimeout(peripheralData.timeout)
            .setTxPowerLevel(peripheralData.txPowerLevel)
            .build()

        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(peripheralData.includeDeviceName)
            .setIncludeTxPowerLevel(peripheralData.includeTxPowerLevel)
            .addServiceUuid(ParcelUuid(UUID.fromString(peripheralData.uuid)))
//            .addManufacturerData()
//            .addServiceData()
//            .addServiceSolicitationUuid()
            .build()

        if (peripheralResponse != null) {
//            val scanResponse = AdvertiseData.Builder()
//                .setIncludeDeviceName(peripheralData.includeDeviceName)
//                .setIncludeTxPowerLevel(peripheralData.includeTxPowerLevel)
//                .addServiceUuid(ParcelUuid(UUID.fromString(peripheralData.uuid)))
//            .addManufacturerData()
//            .addServiceData()
//            .addServiceSolicitationUuid()
//                .build()

//            mBluetoothLeAdvertiser!!.startAdvertising(
//                advertiseSettings,
//                advertiseData,
//                scanResponse,
//                mAdvertiseCallback
//            )
        } else {
            mBluetoothLeAdvertiser!!.startAdvertising(
                advertiseSettings,
                advertiseData,
                mAdvertiseCallback
            )
        }


        // TODO: Add service to advertise
//        addService(peripheralData)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun startSet(peripheralData: PeripheralData, result: MethodChannel.Result) {
        try {
            init(context)
        } catch (e: PeripheralException) {
            handlePeripheralException(e, result)
            return
        }

        val advertiseSettingsSet = AdvertisingSetParameters.Builder()
//            .setAnonymous()
//            .setConnectable()
//            .setIncludeTxPower()
//            .setInterval()
//            .setLegacyMode()
//            .setPrimaryPhy()
//            .setScannable()
//            .setSecondaryPhy()
//            .setTxPowerLevel()
            .build()

//        val advertiseSettings = AdvertiseSettings.Builder()
//            .setAdvertiseMode(peripheralData.advertiseMode)
//            .setConnectable(peripheralData.connectable)
//            .setTimeout(peripheralData.timeout)
//            .setTxPowerLevel(peripheralData.txPowerLevel)
//            .build()

        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(peripheralData.includeDeviceName)
            .setIncludeTxPowerLevel(peripheralData.includeTxPowerLevel)
            .addServiceUuid(ParcelUuid(UUID.fromString(peripheralData.uuid)))
            .build()

        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(peripheralData.includeDeviceName)
            .setIncludeTxPowerLevel(peripheralData.includeTxPowerLevel)
            .addServiceUuid(ParcelUuid(UUID.fromString(peripheralData.uuid)))
//            .addManufacturerData()
//            .addServiceData()
//            .addServiceSolicitationUuid()
            .build()

        val periodicAdvertisingParameters = PeriodicAdvertisingParameters.Builder()
//            .setAnonymous()
//            .setConnectable()
//            .setIncludeTxPower()
//            .setInterval()
//            .setLegacyMode()
//            .setPrimaryPhy()
//            .setScannable()
//            .setSecondaryPhy()
//            .setTxPowerLevel()
            .build()

        val periodicData = AdvertiseData.Builder()
            .setIncludeDeviceName(peripheralData.includeDeviceName)
            .setIncludeTxPowerLevel(peripheralData.includeTxPowerLevel)
            .addServiceUuid(ParcelUuid(UUID.fromString(peripheralData.uuid)))
//            .addManufacturerData()
//            .addServiceData()
//            .addServiceSolicitationUuid()
            .build()

        val duration = 0
        val maxExtendedAdvertisingEvents = 0


        mBluetoothLeAdvertiser!!.startAdvertisingSet(
            advertiseSettingsSet,
            advertiseData,
            scanResponse,
            periodicAdvertisingParameters,
            periodicData,
            duration,
            maxExtendedAdvertisingEvents,
            mAdvertiseSetCallback,
//            handler
        )
//
//        mBluetoothLeAdvertiser!!.startAdvertisingSet(
//            advertiseSettingsSet,
//            advertiseData,
//            scanResponse,
//            periodicAdvertisingParameters,
//            periodicData,
//            mAdvertiseSetCallback
//        )
//
//        mBluetoothLeAdvertiser!!.startAdvertisingSet(
//            advertiseSettingsSet,
//            advertiseData,
//            scanResponse,
//            periodicAdvertisingParameters,
//            periodicData,
//            mAdvertiseSetCallback
//        )

        // TODO: Add service to advertise
//        addService(peripheralData)
    }

    fun isAdvertising(): Boolean {
        return isAdvertising
    }

    fun stop(result: MethodChannel.Result) {
        try {
            init(context)
        } catch (e: PeripheralException) {
            handlePeripheralException(e, result)
            return
        }

        mBluetoothLeAdvertiser!!.stopAdvertising(mAdvertiseCallback)
        isAdvertising = false

        onStateChanged?.invoke(PeripheralState.idle)
    }

    // TODO: Add service to advertise
    private fun addService(peripheralData: PeripheralData) {
        txCharacteristic = BluetoothGattCharacteristic(
            UUID.fromString(peripheralData.txCharacteristicUUID),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        rxCharacteristic = BluetoothGattCharacteristic(
            UUID.fromString(peripheralData.rxCharacteristicUUID),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        val service = BluetoothGattService(
            UUID.fromString(peripheralData.serviceDataUuid),
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )

        val gattCallback = object : BluetoothGattCallback() {
            override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
                onMtuChanged?.invoke(mtu)
            }
        }

        val serverCallback = object : BluetoothGattServerCallback() {
            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
                onMtuChanged?.invoke(mtu)
            }

            override fun onConnectionStateChange(
                device: BluetoothDevice?,
                status: Int,
                newState: Int
            ) {
                when (status) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        mBluetoothDevice = device
                        mBluetoothGatt = mBluetoothDevice?.connectGatt(context, true, gattCallback)
                        onStateChanged?.invoke(PeripheralState.connected)
                        Log.i(tag, "Device connected $device")
                    }

                    BluetoothProfile.STATE_DISCONNECTED -> {
                        onStateChanged?.invoke(PeripheralState.idle)
                        Log.i(tag, "Device disconnect $device")
                    }
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                Log.i(tag, "BLE Read Request")

                val status = when (characteristic.uuid) {
                    rxCharacteristic?.uuid -> BluetoothGatt.GATT_SUCCESS
                    else -> BluetoothGatt.GATT_FAILURE
                }

                mBluetoothGattServer.sendResponse(device, requestId, status, 0, null)
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                Log.i(tag, "BLE Write Request")

                val isValid = value?.isNotEmpty() == true && characteristic == rxCharacteristic

                Log.i(tag, "BLE Write Request - Is valid? $isValid")

                if (isValid) {
                    mBluetoothDevice = device
                    mBluetoothGatt = mBluetoothDevice?.connectGatt(context, true, gattCallback)
                    onStateChanged?.invoke(PeripheralState.connected)

                    onDataReceived?.invoke(value!!)
                    Log.i(tag, "BLE Received Data $peripheralData")
                }

                if (responseNeeded) {
                    Log.i(tag, "BLE Write Request - Response")
                    mBluetoothGattServer.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        null
                    )
                }
            }
        }

        service.addCharacteristic(txCharacteristic)
        service.addCharacteristic(rxCharacteristic)

        mBluetoothGattServer = mBluetoothManager
            .openGattServer(context, serverCallback)
            .also { it.addService(service) }
    }

    fun send(data: ByteArray) {
        txCharacteristic?.let { char ->
            char.value = data
            mBluetoothGatt?.writeCharacteristic(char)
            mBluetoothGattServer.notifyCharacteristicChanged(mBluetoothDevice, char, false)
        }
    }
}
