package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseSettings
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel

class PeripheralAdvertisingCallback(private val result: MethodChannel.Result, private val stateChangedHandler: StateChangedHandler): AdvertiseCallback() {
    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
        super.onStartSuccess(settingsInEffect)
        Log.i("FlutterBlePeripheral", "onStartSuccess() mode: ${settingsInEffect.mode}, txPOWER ${settingsInEffect.txPowerLevel}")
        result.success(null)
        stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
    }

    override fun onStartFailure(errorCode: Int) {
        super.onStartFailure(errorCode)
        val statusText: String
        when (errorCode) {
            ADVERTISE_FAILED_ALREADY_STARTED -> {
                statusText = "ADVERTISE_FAILED_ALREADY_STARTED"
                stateChangedHandler.publishPeripheralState(PeripheralState.advertising)
            }
            ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                statusText = "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                stateChangedHandler.publishPeripheralState(PeripheralState.unsupported)
            }
            ADVERTISE_FAILED_INTERNAL_ERROR -> {
                statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
                stateChangedHandler.publishPeripheralState(PeripheralState.idle)
            }
            ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                stateChangedHandler.publishPeripheralState(PeripheralState.idle)
            }
            ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
                stateChangedHandler.publishPeripheralState(PeripheralState.idle)
            }
            else -> {
                statusText = "UNDOCUMENTED"
                stateChangedHandler.publishPeripheralState(PeripheralState.unknown)
            }
        }
        result.error(errorCode.toString(), statusText, "startAdvertising")
    }
}