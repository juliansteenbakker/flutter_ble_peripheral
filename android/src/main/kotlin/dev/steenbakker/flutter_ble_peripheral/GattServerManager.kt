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
import dev.steenbakker.flutter_ble_peripheral.handlers.DataReceivedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.MtuChangedHandler
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.MessagePacket
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableJob
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import java.security.InvalidParameterException
import java.util.UUID

class GattServerManager(
    private val blePeripheralManager : FlutterBlePeripheralManager,
    private val stateHandler : StateChangedHandler,
    private val dataHandler : DataReceivedHandler,
    private val mtuHandler : MtuChangedHandler,
    context: Context
) : BluetoothGattServerCallback() {
    companion object {
        const val TAG = "BluetoothGattServerCallback"
        val CLIENT_CHARACTERISTIC_CONFIG : UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }


    private val mBluetoothGattServer: BluetoothGattServer
    private val fragmentManager : BleFragmentManager = BleFragmentManager()
    private val devices: HashSet<BluetoothDevice> = HashSet()
    //private val services: HashMap<UUID, BluetoothGattService> = HashMap()
    private val characteristics: HashMap<UUID, ByteArray> = HashMap()
    private val subscriptionManager : SubscriptionManager = SubscriptionManager()

    private var pendingAddServiceResult: MethodChannel.Result? = null
    private var pendingNotification: CompletableJob? = null

    init {
        //TODO: se não tiver permissões, isto falha. Consertar
        mBluetoothGattServer = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).openGattServer(context, this)

        /*
        val service = BluetoothGattService(
            UUID.fromString("bf27730d-860a-4e09-889c-2d8b6a9e0fe7"),
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        val characteristic = BluetoothGattCharacteristic(
            UUID.fromString("2edd3dbe-f1f9-49d6-a88f-e053e69aa5ed"),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        val descriptor = BluetoothGattDescriptor(
            CLIENT_CHARACTERISTIC_CONFIG,
            BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ)

        characteristic.addDescriptor(descriptor)
        service.addCharacteristic(characteristic)
        mBluetoothGattServer.addService(service)
        */
    }

    fun dispose() {
        mBluetoothGattServer.close()
    }


    fun addService(serviceUUID: UUID, chars: Map<BluetoothGattCharacteristic,ByteArray>, result: MethodChannel.Result) {
        if (pendingAddServiceResult != null) {
            result.error("Duplicate request", "Already creating a service", null)
            return
        }

        val service = BluetoothGattService(serviceUUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        for ((char, value) in chars) {
            characteristics[char.uuid] = value
            service.addCharacteristic(char)
        }

        mBluetoothGattServer.addService(service)
        pendingAddServiceResult = result
    }

    fun removeService(serviceUUID : UUID) : Boolean {
        for (c in mBluetoothGattServer.getService(serviceUUID).characteristics) {
            characteristics.remove(c.uuid)
            subscriptionManager.removeCharacteristicData(c.uuid)
        }

        return mBluetoothGattServer.removeService(mBluetoothGattServer.getService(serviceUUID))
    }

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

    private fun notifyDevice(device : BluetoothDevice, characteristic: BluetoothGattCharacteristic, confirm : Boolean, data: ByteArray) {
        //TODO: fragment when data.size() > mtu???
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            mBluetoothGattServer.notifyCharacteristicChanged(device, characteristic, confirm, data)
        } else {
            characteristic.setValue(data)
            mBluetoothGattServer.notifyCharacteristicChanged(device, characteristic, confirm)
        }
    }

    fun write(characteristic : UUID, data : ByteArray, result : MethodChannel.Result? = null) {
        characteristics[characteristic] = data
        dataHandler.publishData(MessagePacket(characteristic, data))

        val c = getCharacteristic(characteristic)

        runBlocking {
            for ((device, confirm) in subscriptionManager.subscriptions(characteristic)) {
                pendingNotification = Job()
                notifyDevice(device, c, confirm, data)
                pendingNotification!!.join() //wait for onNotificationSent
                pendingNotification = null
            }

            result?.success(null)
        }
    }

    override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
        super.onServiceAdded(status, service)
        pendingAddServiceResult!!.success(status == BluetoothGatt.GATT_SUCCESS)
        pendingAddServiceResult = null
    }

    override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
        super.onConnectionStateChange(device, status, newState)
        if (newState == BluetoothProfile.STATE_CONNECTED) {
            Log.i(TAG, "onConnectionStateChange $status CONNECTED")
            devices.add(device)
            blePeripheralManager.stop()
            stateHandler.publishPeripheralState(PeripheralState.connected)
        } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            Log.i(TAG, "onConnectionStateChange $status DISCONNECTED")
            subscriptionManager.removeDeviceData(device)
            devices.remove(device)
            if (devices.size == 0)
                stateHandler.publishPeripheralState(PeripheralState.idle) //TODO: or powered off (detect elsewhere?)
        }
    }

    override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
        super.onMtuChanged(device, mtu)
        mtuHandler.publishMtu(mtu)
    }

    override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
        super.onNotificationSent(device, status)
        if (status != BluetoothGatt.GATT_SUCCESS)
            Log.w(TAG, "Error sending notification. status code: $status")

        pendingNotification!!.complete()
    }

    override fun onCharacteristicReadRequest(
        device: BluetoothDevice,
        requestId: Int,
        offset: Int,
        characteristic: BluetoothGattCharacteristic
    ) {
        super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
        Log.i(TAG, "onCharacteristicReadRequest ${characteristic.uuid}")

        val data = read(characteristic.uuid)
        if (data != null && characteristic.permissions and BluetoothGattCharacteristic.PERMISSION_READ != 0)
            //TODO: fragment when data.size() > mtu???
            mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, data)
        else
            mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
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

        if (characteristic.permissions and BluetoothGattCharacteristic.PERMISSION_WRITE == 0) {
            Log.w(TAG, "Attempt to write a characteristic without writing permission: ${characteristic.uuid}")
            if (responseNeeded) {
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
            }
        } else {
            if (preparedWrite) {
                fragmentManager.pushFragment(device, characteristic.uuid, value)
            } else {
                write(characteristic.uuid, value)
            }

            if (responseNeeded) {
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }
        }
    }

    override fun onDescriptorReadRequest (
        device : BluetoothDevice,
        requestId : Int,
        offset : Int,
        descriptor : BluetoothGattDescriptor
    ) {
        super.onDescriptorReadRequest(device, requestId, offset, descriptor)
        Log.i(TAG, "onDescriptorReadRequest ${descriptor.uuid}")

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
        //TODO: check for responseNeeded instead of always responding

        if (descriptor.permissions and BluetoothGattDescriptor.PERMISSION_WRITE == 0) {
            Log.w(TAG, "Attempt to write a descriptor without writing permission: ${descriptor.uuid}")
            mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
        } else {
            assert(descriptor.uuid == CLIENT_CHARACTERISTIC_CONFIG) //No other descriptors are implemented

            if (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                && descriptor.characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
            ) {
                Log.i(TAG, "NOTIFICATIONS ENABLED")
                subscriptionManager.subscribe(device, descriptor.characteristic.uuid, false)
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            } else if (value.contentEquals(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
                && descriptor.characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
            ) {
                Log.i(TAG, "INDICATIONS ENABLED")
                subscriptionManager.subscribe(device, descriptor.characteristic.uuid, true)
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            } else if (value.contentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)) {
                Log.i(TAG, "NOTIFICATIONS/INDICATIONS DISABLED")
                subscriptionManager.unsubscribe(device, descriptor.characteristic.uuid)
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            } else {
                Log.w(TAG, "Invalid write attempt to descriptor of characteristic ${descriptor.characteristic.uuid}")
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
            }
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