package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseSettings
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.util.Timer
import kotlin.concurrent.timerTask

class PeripheralAdvertisingCallback(
    private val result: MethodChannel.Result,
    private val stateChangedHandler: StateChangedHandler,
    private val duration: Long //in milliseconds
): AdvertiseCallback() {
    companion object {
        const val TAG: String = "PeripheralAdvertisingCallback"
    }

    private var timer : Timer? = Timer()

    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
        super.onStartSuccess(settingsInEffect)
        Log.i(TAG, "onStartSuccess() mode: ${settingsInEffect.mode}, txPOWER ${settingsInEffect.txPowerLevel}")
        stateChangedHandler.advertising = true
        result.success(null)

        timer?.schedule(timerTask {
            dispose()
        }, duration)
    }

    fun dispose() {
        if (timer != null) {
            stateChangedHandler.advertising = false
            timer!!.cancel()
            timer = null
        }
    }

    override fun onStartFailure(errorCode: Int) {
        super.onStartFailure(errorCode)
        timer!!.cancel()
        timer = null

        val statusText: String
        when (errorCode) {
            ADVERTISE_FAILED_ALREADY_STARTED -> {
                stateChangedHandler.advertising = true
                result.error("DuplicatedOperation", "Already advertising", "startAdvertising")
                return
            }
            ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                stateChangedHandler.advertising = false
                result.error("UnsupportedOperation", "Advertising is not supported on this platform", "startAdvertising")
                return
            }
            ADVERTISE_FAILED_INTERNAL_ERROR -> {
                statusText = "ADVERTISE_FAILED_INTERNAL_ERROR"
            }
            ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> {
                statusText = "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
            }
            ADVERTISE_FAILED_DATA_TOO_LARGE -> {
                statusText = "ADVERTISE_FAILED_DATA_TOO_LARGE"
            }
            else -> {
                statusText = "UNDOCUMENTED"
            }
        }

        stateChangedHandler.advertising = false
        result.error(errorCode.toString(), statusText, "startAdvertising")
    }
}