package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Intent
import androidx.core.app.ActivityCompat
import io.flutter.Log
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

class ActivityResultCallback(private val activity : Activity) : ActivityResultListener {

    companion object {
        const val REQUEST_ENABLE_BT = 4
        const val TAG: String = "EnableBluetoothCallback"
    }

    private var callback: ((Int) -> Unit)? = null

    fun enableBluetooth(callback: (Int) -> Unit) {
        if (this.callback != null) {
            Log.w(TAG, "Duplicate call before response. Ignoring...")
            return
        }

        this.callback = callback
        ActivityCompat.startActivityForResult(
            activity,
            Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
            REQUEST_ENABLE_BT,
            null
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_ENABLE_BT) {
            //TODO: error checking
            //if (resultCode != Activity.RESULT_OK) ...

            callback!!(resultCode)
            callback = null
            return true
        }

        this.callback = null
        return false
    }
}