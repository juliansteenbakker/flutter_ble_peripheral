package dev.steenbakker.flutter_ble_peripheral

import android.Manifest.permission
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

@RequiresApi(Build.VERSION_CODES.S)
internal class BluetoothPermission {
    internal interface PermissionsRegistry {
        fun addListener(
                handler: RequestPermissionsResultListener?)
    }

    internal interface ResultCallback {
        fun onResult(errorCode: String?, errorDescription: String?)
    }

    private var ongoing = false

    fun requestPermissions(
            activity: Activity,
            permissionsRegistry: PermissionsRegistry,
            callback: ResultCallback) {
        if (ongoing) {
            callback.onResult("bluetoothPermission", "Bluetooth permission request ongoing")
        }
        if (!hasBluetoothAdvertisePermission(activity) || !hasBluetoothConnectPermission(activity) || !hasBluetoothScanPermission(activity)) {
            permissionsRegistry.addListener(
                    BluetoothRequestPermissionsListener(
                            object : ResultCallback {
                                override fun onResult(errorCode: String?, errorDescription: String?) {
                                    ongoing = false
                                    callback.onResult(errorCode, errorDescription)
                                }
                            }))
            ongoing = true
            ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(permission.BLUETOOTH_SCAN, permission.BLUETOOTH_CONNECT, permission.BLUETOOTH_ADVERTISE),
                    BLUETOOTH_REQUEST_ID)
        } else {
            // Permissions already exist. Call the callback with success.
            callback.onResult(null, null)
        }
    }

    // Permissions for Bluetooth API > 31
    private fun hasBluetoothAdvertisePermission(activity: Activity): Boolean {
        return (ContextCompat.checkSelfPermission(activity, permission.BLUETOOTH_ADVERTISE)
                == PackageManager.PERMISSION_GRANTED)
    }


    private fun hasBluetoothConnectPermission(activity: Activity): Boolean {
        return (ContextCompat.checkSelfPermission(activity, permission.BLUETOOTH_CONNECT)
                == PackageManager.PERMISSION_GRANTED)
    }

    private fun hasBluetoothScanPermission(activity: Activity): Boolean {
        return (ContextCompat.checkSelfPermission(activity, permission.BLUETOOTH_SCAN)
                == PackageManager.PERMISSION_GRANTED)
    }

    internal class BluetoothRequestPermissionsListener constructor(private val callback: ResultCallback) : RequestPermissionsResultListener {
        // There's no way to unregister permission listeners in the v1 embedding, so we'll be called
        // duplicate times in cases where the user denies and then grants a permission. Keep track of if
        // we've responded before and bail out of handling the callback manually if this is a repeat
        // call.
        var alreadyCalled = false
        override fun onRequestPermissionsResult(id: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
            if (alreadyCalled || id != BLUETOOTH_REQUEST_ID) {
                return false
            }
            alreadyCalled = true
            if (grantResults[0] != PackageManager.PERMISSION_GRANTED) {
                callback.onResult("bluetoothScanPermission", "Bluetooth scan permission not granted")
            } else if (grantResults.size > 1 && grantResults[1] != PackageManager.PERMISSION_GRANTED) {
                callback.onResult("bluetoothConnectPermission", "Bluetooth connect permission not granted")
            } else if (grantResults.size > 2 && grantResults[2] != PackageManager.PERMISSION_GRANTED) {
                callback.onResult("bluetoothAdvertisePermission", "Bluetooth advertise permission not granted")
            } else {
                callback.onResult(null, null)
            }
            return true
        }
    }

    companion object {
        private const val BLUETOOTH_REQUEST_ID = 9796
    }
}