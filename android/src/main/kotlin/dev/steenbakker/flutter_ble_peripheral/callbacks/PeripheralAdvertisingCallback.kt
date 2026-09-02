package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseSettings
import android.os.Handler
import android.os.Looper
import dev.steenbakker.flutter_ble_peripheral.handlers.PeripheralStateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralBluetoothState
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel

class PeripheralAdvertisingCallback(private val result: MethodChannel.Result, private val peripheralStateChangedHandler: PeripheralStateChangedHandler): AdvertiseCallback() {
    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
        super.onStartSuccess(settingsInEffect)
        Log.i("FlutterBlePeripheral", "onStartSuccess() mode: ${settingsInEffect.mode}, txPOWER ${settingsInEffect.txPowerLevel}")
        // The thread this callback arrives on is not part of the contract, and a
        // result may only be sent from the main thread.
        Handler(Looper.getMainLooper()).post {
            result.success(PeripheralBluetoothState.Ready.ordinal)
        }
        peripheralStateChangedHandler.publish(PeripheralState.advertising)
    }

    override fun onStartFailure(errorCode: Int) {
        super.onStartFailure(errorCode)
        val statusText: String
        Log.i("FlutterBlePeripheral", "onStartFailure() error: $errorCode")
        when (errorCode) {
            ADVERTISE_FAILED_ALREADY_STARTED -> {
                statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                peripheralStateChangedHandler.publish(PeripheralState.advertising)
            }
            ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                peripheralStateChangedHandler.publish(PeripheralState.unsupported)
            }
            ADVERTISE_FAILED_INTERNAL_ERROR -> {
                statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                peripheralStateChangedHandler.publish(PeripheralState.idle)
            }
            ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                peripheralStateChangedHandler.publish(PeripheralState.idle)
            }
            ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                peripheralStateChangedHandler.publish(PeripheralState.idle)
            }
            else -> {
                statusText = "UNDOCUMENTED"
                peripheralStateChangedHandler.publish(PeripheralState.unknown)
            }
        }
        Handler(Looper.getMainLooper()).post {
            result.error(errorCode.toString(), statusText, "startAdvertising")
        }
    }
}