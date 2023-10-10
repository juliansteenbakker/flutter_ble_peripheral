package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.os.Build
import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import dev.steenbakker.flutter_ble_peripheral.models.State
import io.flutter.plugin.common.PluginRegistry
import io.flutter.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class PermissionCallback(binding : ActivityPluginBinding) : PluginRegistry.RequestPermissionsResultListener {
    companion object {
        const val REQUEST_PERMISSION_BT = 8
        const val TAG: String = "RequestPermissionsHandler"

        // Permissions for Bluetooth API >= 31
        @RequiresApi(Build.VERSION_CODES.S)
        private fun hasBluetoothAdvertisePermission(context: Context): Boolean {
            return (context.checkSelfPermission(
                Manifest.permission.BLUETOOTH_ADVERTISE
            )
                    == PackageManager.PERMISSION_GRANTED)
        }
        @RequiresApi(Build.VERSION_CODES.S)
        private fun hasBluetoothConnectPermission(context: Context): Boolean {
            return (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                    == PackageManager.PERMISSION_GRANTED)
        }

        // Permissions for Bluetooth API < 31
        @RequiresApi(Build.VERSION_CODES.M)
        private fun hasLocationFinePermission(context: Context): Boolean {
            return (context.checkSelfPermission(
                Manifest.permission.ACCESS_FINE_LOCATION
            )
                    == PackageManager.PERMISSION_GRANTED)
        }
        @RequiresApi(Build.VERSION_CODES.M)
        private fun hasLocationCoarsePermission(context: Context): Boolean {
            return (context.checkSelfPermission(
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
                    == PackageManager.PERMISSION_GRANTED)
        }

        fun hasPermissions(activity : Context) : Boolean
        {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                return hasLocationCoarsePermission(activity) && hasLocationFinePermission(activity)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return hasBluetoothAdvertisePermission(activity) && hasBluetoothConnectPermission(activity)
            }

            Log.e(TAG, "Unknown build version: ${Build.VERSION.SDK_INT}")
            return false
        }

        fun permissionState(activity : Activity) : State {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                return if (hasLocationCoarsePermission(activity) && hasLocationFinePermission(activity))
                    State.Granted
                else if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_COARSE_LOCATION) ||
                    ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_FINE_LOCATION))
                    State.Denied
                else
                    State.PermanentlyDenied
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                return if (hasBluetoothAdvertisePermission(activity) && hasBluetoothConnectPermission(activity))
                    State.Granted
                else if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.BLUETOOTH_ADVERTISE) ||
                    ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.BLUETOOTH_CONNECT))
                    State.Denied
                else
                    State.PermanentlyDenied

            Log.e(TAG, "Unknown build version: ${Build.VERSION.SDK_INT}")
            return State.Unknown
        }
    }

    private val activity = binding.activity
    private var callback: ((State) -> Unit)? = null

    init {
        binding.addRequestPermissionsResultListener(this)
    }

    fun requestPermission(callback: (State) -> Unit) {
        if (this.callback != null) {
            Log.w(TAG, "Duplicate call to requestPermission before response. Ignoring...")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            (!hasBluetoothAdvertisePermission(activity) || !hasBluetoothConnectPermission(activity))
        ) {
            this.callback = callback
            ActivityCompat.requestPermissions(activity,
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE),
                    REQUEST_PERMISSION_BT
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            (!hasLocationCoarsePermission(activity) || !hasLocationFinePermission(activity))
        ) {
            this.callback = callback
            ActivityCompat.requestPermissions(activity,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                    REQUEST_PERMISSION_BT
            )
        } else {
            callback(State.Granted)
        }
    }

    override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<out String>,
            grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_PERMISSION_BT) {
            callback!!(permissionState(activity))
            callback = null
            return true
        }

        return false
    }
}