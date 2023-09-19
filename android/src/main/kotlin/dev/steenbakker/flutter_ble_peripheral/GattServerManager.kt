package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import dev.steenbakker.flutter_ble_peripheral.exceptions.PeripheralException
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.MessagePacket
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import java.security.InvalidParameterException
import java.util.UUID

class GattServerManager(
    private val blePeripheralManager : FlutterBlePeripheralManager,
    private val stateHandler : StateChangedHandler,
    private val dataHandler : DataReceivedHandler,
    private val mtuHandler : MtuChangedHandler,
    context : Context
) : BluetoothGattServerCallback() {
    companion object {
        const val TAG = "GattServerManager"
        val CLIENT_CHARACTERISTIC_CONFIG : UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }


    private val mBluetoothGattServer: BluetoothGattServer
    private val devices: HashSet<BluetoothDevice> = HashSet()
    private val characteristics: HashMap<UUID, ByteArray> = HashMap()
    private val subscriptionManager : SubscriptionManager = SubscriptionManager()
    private val fragmentManager : BleFragmentManager = BleFragmentManager()

    private val addServiceQueue: JobQueue = JobQueue()
    private val notificationQueue : JobQueue = JobQueue()
    private val disconnectionQueue: JobQueue = JobQueue()

    private var pendingAddService: CompletableDeferred<Int>? = null
    private var pendingNotification: CompletableDeferred<Int>? = null
    private var pendingDisconnection: CompletableDeferred<Int>? = null
    private var disconnectingDevice: BluetoothDevice? = null

    init {
        val mBluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            ?: throw PeripheralException(PeripheralState.unsupported)

        mBluetoothGattServer = mBluetoothManager.openGattServer(context, this)
    }

    fun dispose() {
        mBluetoothGattServer.close()
        addServiceQueue.cancel()
        notificationQueue.cancel()
        disconnectionQueue.cancel()
    }

    fun addService(serviceUUID: UUID, chars: Map<BluetoothGattCharacteristic,ByteArray>, result: MethodChannel.Result) {
        if (mBluetoothGattServer.services.any{ it.uuid == serviceUUID }) {
            return result.success(false)
        }

        val service = BluetoothGattService(serviceUUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        for ((char, value) in chars) {
            if (characteristics.containsKey(char.uuid)) {
                result.error("InvalidCharacteristicUUID", "Characteristic uuid already exists", char.uuid.toString())

                for ((char2,_) in chars)
                    characteristics.remove(char2.uuid)

                return
            }

            characteristics[char.uuid] = value
            service.addCharacteristic(char)
        }

        addServiceQueue.submit {
            if (pendingAddService != null) {
                Log.wtf(TAG, "pendingAddService wasn't reset to null. This can indicate an error creating a previous service")
            }

            pendingAddService = CompletableDeferred()
            mBluetoothGattServer.addService(service)
            val status = pendingAddService!!.await()
            pendingAddService = null

            if (status != BluetoothGatt.GATT_SUCCESS) {
                result.error(status.toString(),"addService failed", TAG)
            } else {
                result.success(true)
            }
        }
    }

    fun removeService(serviceUUID : UUID) : Boolean {
        mBluetoothGattServer.getService(serviceUUID)?.characteristics?.forEach {
            characteristics.remove(it.uuid)
            subscriptionManager.removeCharacteristicData(it.uuid)
        }

        val service = mBluetoothGattServer.getService(serviceUUID) ?: return false
        return mBluetoothGattServer.removeService(service)
    }

    /**
     * Returns the current value of the characteristic, or null if the characteristic doesn't exist
     */
    fun read(uuid : UUID) : ByteArray? {
        return characteristics[uuid]
    }

    private fun getCharacteristic(uuid : UUID) : BluetoothGattCharacteristic {
        for (service in mBluetoothGattServer.services) {
            val characteristic = service.getCharacteristic(uuid)
            if (characteristic != null)
                return characteristic
        }

        throw InvalidParameterException("The characteristic with id '$uuid' doesn't exist")
    }

    /**
     * Sends a notification to a single device
     *
     * Returns whether the notification was sent successfully
     */
    private suspend fun notifyDevice(device : BluetoothDevice, characteristic: BluetoothGattCharacteristic, confirm : Boolean, data: ByteArray): Boolean {
        if (pendingNotification != null) {
            Log.wtf(TAG, "pendingNotification wasn't reset to null. This can indicate an error sending notifications")
        }

        pendingNotification = CompletableDeferred()

        //TODO: fragment when data.size() > mtu???
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            mBluetoothGattServer.notifyCharacteristicChanged(device, characteristic, confirm, data)
        } else {
            characteristic.setValue(data)
            mBluetoothGattServer.notifyCharacteristicChanged(device, characteristic, confirm)
        }

        val status = pendingNotification!!.await() //wait for onNotificationSent
        pendingNotification = null
        return status == BluetoothGatt.GATT_SUCCESS
    }

    /**
     * Stores the information immediately and sends notifications for any connected devices asynchronously
     *
     * The result, if specified, is resolved after all notifications are sent
     */
    fun write(characteristic : UUID, data : ByteArray, result : MethodChannel.Result? = null) {
        characteristics[characteristic] = data
        dataHandler.publishData(MessagePacket(characteristic, data))
        val c = getCharacteristic(characteristic)

        notificationQueue.submit {
            for ((device, confirm) in subscriptionManager.subscriptions(characteristic)) {
                notifyDevice(device, c, confirm, data)
            }

            result?.success(null)
        }
    }

    /**
     * Cancels the connection with the specified device
     *
     * Returns whether the device disconnected successfully
     */
    private suspend fun disconnectDevice(device : BluetoothDevice): Boolean {
        if (pendingDisconnection != null) {
            Log.wtf(TAG, "pendingDisconnection wasn't reset to null. This can indicate an error disconnecting")
        }

        pendingDisconnection = CompletableDeferred()

        disconnectingDevice = device
        mBluetoothGattServer.cancelConnection(device)

        val status = pendingDisconnection!!.await() //wait for onConnectionStateChange
        pendingDisconnection = null
        return status == BluetoothGatt.GATT_SUCCESS
    }

    /**
     * Disconnects all connected devices
     *
     * The result, if specified, is resolved after all devices disconnected
     */
    fun disconnect(result : MethodChannel.Result? = null) {
        disconnectionQueue.submit {
            for (device in devices) {
                disconnectDevice(device)
            }

            result?.success(null)
        }
    }


    override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
        super.onServiceAdded(status, service)
        pendingAddService!!.complete(status)
    }

    override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
        super.onConnectionStateChange(device, status, newState)

        when (newState) {
            BluetoothProfile.STATE_CONNECTED -> {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "onConnectionStateChange CONNECTED")
                    mBluetoothGattServer.connect(device, false)
                    devices.add(device)
                    stateHandler.connected = true
                    blePeripheralManager.stop()
                } else {
                    Log.e(TAG, "onConnectionStateChange CONNECTED status: $status")
                }
            }

            BluetoothProfile.STATE_DISCONNECTED -> {
                if (device == disconnectingDevice) {
                    pendingDisconnection!!.complete(status)
                    disconnectingDevice = null
                }

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "onConnectionStateChange DISCONNECTED")
                    subscriptionManager.removeDeviceData(device)
                    devices.remove(device)

                    if (devices.size == 0)
                        stateHandler.connected = false
                } else {
                    Log.e(TAG, "onConnectionStateChange DISCONNECTED status: $status")
                    return
                }
            }
        }
    }

    override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
        super.onMtuChanged(device, mtu)
        mtuHandler.publishMtu(mtu) //TODO: per connected device
    }

    override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS)
            Log.w(TAG, "Error sending notification. status code: $status")

        super.onNotificationSent(device, status)
        pendingNotification!!.complete(status)
    }

    override fun onCharacteristicReadRequest(
        device: BluetoothDevice,
        requestId: Int,
        offset: Int,
        characteristic: BluetoothGattCharacteristic
    ) {
        super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
        Log.i(TAG, "onCharacteristicReadRequest $requestId ${characteristic.uuid} $offset")

        val data = read(characteristic.uuid)
        if (data == null || (characteristic.permissions and BluetoothGattCharacteristic.PERMISSION_READ == 0)) {
            mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
            return
        }

        val ans = ByteArray(maxOf(0, data.size - offset))
        for (i in offset..< data.size)
            ans[i - offset] = data[i]

        mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, data)
    }

    override fun onCharacteristicWriteRequest(
        device: BluetoothDevice,
        requestId: Int,
        characteristic: BluetoothGattCharacteristic,
        preparedWrite: Boolean,
        responseNeeded: Boolean,
        offset: Int,
        value: ByteArray
    ) {
        super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
        Log.i(TAG, "onCharacteristicWriteRequest $requestId ${characteristic.uuid} $preparedWrite $responseNeeded $offset")

        val hasPermission = characteristic.permissions and BluetoothGattCharacteristic.PERMISSION_WRITE != 0
        val status = if (hasPermission) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_FAILURE

        if (responseNeeded)
            mBluetoothGattServer.sendResponse(device, requestId, status, 0, null)

        if (!hasPermission) {
            Log.w(TAG, "Attempt to write a characteristic without writing permission: ${characteristic.uuid}")
        } else if (preparedWrite) {
            fragmentManager.pushFragment(device, characteristic.uuid, value)
        } else {
            write(characteristic.uuid, value)
        }
    }

    override fun onDescriptorReadRequest (
        device : BluetoothDevice,
        requestId : Int,
        offset : Int,
        descriptor : BluetoothGattDescriptor
    ) {
        super.onDescriptorReadRequest(device, requestId, offset, descriptor)
        Log.i(TAG, "onDescriptorReadRequest  $requestId ${descriptor.characteristic.uuid} ${descriptor.uuid} $offset")

        if (descriptor.uuid == CLIENT_CHARACTERISTIC_CONFIG
            && descriptor.permissions and BluetoothGattDescriptor.PERMISSION_READ != 0
        ) {
            val value = subscriptionManager.getRawValue(device, descriptor.characteristic.uuid)
            mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
        } else {
            Log.w(TAG, "Invalid read attempt to descriptor of characteristic ${descriptor.characteristic.uuid}")
            mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
        }
    }

    override fun onDescriptorWriteRequest (
        device : BluetoothDevice,
        requestId : Int,
        descriptor : BluetoothGattDescriptor,
        preparedWrite : Boolean,
        responseNeeded : Boolean,
        offset : Int,
        value: ByteArray
    ) {
        super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
        val hasPermission = descriptor.permissions and BluetoothGattDescriptor.PERMISSION_WRITE != 0
        var status = BluetoothGatt.GATT_FAILURE

        if (!hasPermission) {
            Log.w(TAG, "Attempt to write to a descriptor without writing permission: ${descriptor.uuid}")
        } else if (descriptor.uuid != CLIENT_CHARACTERISTIC_CONFIG) {
            Log.w(TAG, "Attempt to write to a non-existent descriptor: ${descriptor.uuid}")
        } else if (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
            if (descriptor.characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY == 0) {
                Log.w(TAG, "Attempt to enable notifications without proper property settings")
            } else {
                Log.i(TAG, "NOTIFICATIONS ENABLED")
                subscriptionManager.subscribe(device, descriptor.characteristic.uuid, false)
                status = BluetoothGatt.GATT_SUCCESS
            }
        } else if (value.contentEquals(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)) {
            if (descriptor.characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE == 0) {
                Log.w(TAG, "Attempt to enable indications without proper property settings")
            } else {
                Log.i(TAG, "INDICATIONS ENABLED")
                subscriptionManager.subscribe(device, descriptor.characteristic.uuid, true)
                status = BluetoothGatt.GATT_SUCCESS
            }
        } else if (value.contentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)) {
            Log.i(TAG, "NOTIFICATIONS/INDICATIONS DISABLED")
            subscriptionManager.unsubscribe(device, descriptor.characteristic.uuid)
            status = BluetoothGatt.GATT_SUCCESS
        } else {
            Log.w(TAG, "Attempt to write an invalid value to descriptor: '$value'")
        }

        if (responseNeeded) {
            mBluetoothGattServer.sendResponse(device, requestId, status, 0, null)
        }
    }

    override fun onExecuteWrite(device : BluetoothDevice, requestId : Int, execute : Boolean) {
        super.onExecuteWrite(device, requestId, execute)
        Log.i(TAG, "onExecuteWrite $requestId $execute")

        val data : HashMap<UUID,ByteArray> = fragmentManager.popData(device)
        if (execute) {
            for ((key, value) in data) {
                write(key, value)
            }
        }
    }
}