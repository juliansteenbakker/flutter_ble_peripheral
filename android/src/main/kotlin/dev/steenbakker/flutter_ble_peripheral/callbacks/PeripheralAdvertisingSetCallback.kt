package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.bluetooth.le.AdvertisingSet
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.Build
import androidx.annotation.RequiresApi
import dev.steenbakker.flutter_ble_peripheral.handlers.StateChangedHandler
import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel

@RequiresApi(Build.VERSION_CODES.O)
class PeripheralAdvertisingSetCallback(private val result: MethodChannel.Result, private val stateChangedHandler: StateChangedHandler): AdvertisingSetCallback() {
    companion object {
        const val TAG : String = "PeripheralAdvertisingSetCallback"
    }

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
        Log.i(TAG, "onAdvertisingSetStarted() status: $advertisingSet, txPOWER $txPower, status $status")
        super.onAdvertisingSetStarted(advertisingSet, txPower, status)
        val statusText : String
        when (status) {
            ADVERTISE_SUCCESS -> {
                stateChangedHandler.advertising = true
                result.success(txPower)
                return
            }
            ADVERTISE_FAILED_ALREADY_STARTED -> {
                stateChangedHandler.advertising = true
                result.error("DuplicatedOperation", "Already advertising", "startAdvertisingSet")
                return
            }
            ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> {
                stateChangedHandler.advertising = false
                result.error("UnsupportedOperation", "Advertising is not supported on this platform", "startAdvertisingSet")
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
        result.error(status.toString(), statusText, TAG)
    }

    /**
     * Callback triggered in response to [BluetoothLeAdvertiser.stopAdvertisingSet]
     * indicating advertising set is stopped.
     *
     * @param advertisingSet The advertising set.
     */
    override fun onAdvertisingSetStopped(advertisingSet: AdvertisingSet?) {
        Log.i(TAG, "onAdvertisingSetStopped() status: $advertisingSet")
        super.onAdvertisingSetStopped(advertisingSet)
        stateChangedHandler.advertising = false
    }

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
        Log.i(TAG, "onAdvertisingEnabled() status: $advertisingSet, enable $enable, status $status")
        super.onAdvertisingEnabled(advertisingSet, enable, status)
        stateChangedHandler.advertising = true
    }
}