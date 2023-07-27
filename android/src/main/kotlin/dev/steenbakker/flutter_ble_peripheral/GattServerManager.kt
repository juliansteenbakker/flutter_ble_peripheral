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
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableJob
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
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
        const val TAG = "BluetoothGattServerCallback"
        val CLIENT_CHARACTERISTIC_CONFIG : UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }


    private val mBluetoothGattServer: BluetoothGattServer
    private val devices: HashSet<BluetoothDevice> = HashSet()
    private val characteristics: HashMap<UUID, ByteArray> = HashMap()
    private val subscriptionManager : SubscriptionManager = SubscriptionManager()
    private val fragmentManager : BleFragmentManager = BleFragmentManager()
    private val notificationQueue : JobQueue = JobQueue()

    private var pendingAddServiceResult: MethodChannel.Result? = null
    private var pendingNotification: CompletableJob? = null


    private val scope = CoroutineScope(Dispatchers.Main)

    init {
        //TODO: exception if fail
        mBluetoothGattServer = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).openGattServer(context, this)
    }

    fun dispose() {
        mBluetoothGattServer.close()
    }


    fun addService(serviceUUID: UUID, chars: Map<BluetoothGattCharacteristic,ByteArray>, result: MethodChannel.Result) {
        if (mBluetoothGattServer.services.any{ it.uuid == serviceUUID }) {
            //TODO: check if the existent characteristics match the requested characteristics?
            return result.success(false)
        }

        if (pendingAddServiceResult != null) {
            //TODO: BUG FIX somehow, I was once able to set pendingAddServiceResult permanently. This prevented any services from being created
            return result.error("DuplicatedOperation", "Already creating a service", "GattServerManager")
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

        mBluetoothGattServer.addService(service)
        pendingAddServiceResult = result
    }

    fun removeService(serviceUUID : UUID) : Boolean {
        mBluetoothGattServer.getService(serviceUUID)?.characteristics?.forEach {
            characteristics.remove(it.uuid)
            subscriptionManager.removeCharacteristicData(it.uuid)
        }

        val service = mBluetoothGattServer.getService(serviceUUID) ?: return false
        return mBluetoothGattServer.removeService(service)
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

    private suspend fun notifyDevice(device : BluetoothDevice, characteristic: BluetoothGattCharacteristic, confirm : Boolean, data: ByteArray) {
        if (pendingNotification != null) {
            Log.wtf(TAG, "pendingNotification wasn't reset to null. This can indicate an error sending notifications")
        }

        pendingNotification = Job()

        //TODO: fragment when data.size() > mtu???
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            mBluetoothGattServer.notifyCharacteristicChanged(device, characteristic, confirm, data)
        } else {
            characteristic.setValue(data)
            mBluetoothGattServer.notifyCharacteristicChanged(device, characteristic, confirm)
        }

        pendingNotification!!.join() //wait for onNotificationSent
        pendingNotification = null
    }

    //Stores the information immediately and sends notifications for any connected devices asynchronously
    fun write(characteristic : UUID, data : ByteArray, result : MethodChannel.Result? = null) {
        characteristics[characteristic] = data
        dataHandler.publishData(MessagePacket(characteristic, data))
        result?.success(null)

        val c = getCharacteristic(characteristic)

        for ((device, confirm) in subscriptionManager.subscriptions(characteristic)) {
            notificationQueue.submit {
                notifyDevice(device, c, confirm, data)
            }
        }
    }

    fun disconnect() {
        for (device in devices) {
            mBluetoothGattServer.cancelConnection(device)
        }
    }


    override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
        super.onServiceAdded(status, service)
        if (status != BluetoothGatt.GATT_SUCCESS) { //TODO: decode status
            pendingAddServiceResult!!.error(status.toString(),"addService failed", "GattServerManager")
        } else {
            pendingAddServiceResult!!.success(true)
        }

        pendingAddServiceResult = null
    }

    override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
        super.onConnectionStateChange(device, status, newState)

        if (status == BluetoothGatt.GATT_SUCCESS) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i(TAG, "onConnectionStateChange CONNECTED")
                mBluetoothGattServer.connect(device, false)
                devices.add(device)
                stateHandler.connected = true
                blePeripheralManager.stop()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.i(TAG, "onConnectionStateChange DISCONNECTED")
                subscriptionManager.removeDeviceData(device)
                devices.remove(device)
                if (devices.size == 0)
                    stateHandler.connected = false
            }
        } else { //TODO: treat the error somehow?
            Log.e(TAG, "onConnectionStateChange: status $status, newState $newState")
        }

        //TODO: ao brincar com o BLEScanner (a app), é possivel desconectar sem mudar o PeripheralState. Corrigir
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
            if (responseNeeded) {
                mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }

            if (preparedWrite) {
                fragmentManager.pushFragment(device, characteristic.uuid, value)
            } else {
                write(characteristic.uuid, value)
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