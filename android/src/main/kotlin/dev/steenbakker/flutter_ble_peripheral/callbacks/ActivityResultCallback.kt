package dev.steenbakker.flutter_ble_peripheral.callbacks

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Intent
import androidx.core.app.ActivityCompat
import io.flutter.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

class ActivityResultCallback(binding : ActivityPluginBinding) : ActivityResultListener {

    companion object {
        const val REQUEST_ENABLE_BT = 4
        const val TAG: String = "ActivityResultCallback"
    }

    private val activity = binding.activity
    private var callback: ((Int) -> Unit)? = null
    private var requestCode: Int? = null

    init {
        binding.addActivityResultListener(this)
    }

    fun enableBluetooth(callback: (Int) -> Unit) {
        if (this.callback != null) {
            Log.w(TAG, "Duplicate call before response. Ignoring...")
            return
        }

        this.callback = callback
        this.requestCode = REQUEST_ENABLE_BT
        ActivityCompat.startActivityForResult(
            activity,
            Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
            requestCode!!,
            null
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == this.requestCode!!) {
            callback!!(resultCode)
            callback = null
            this.requestCode = null
            return true
        }

        callback = null
        this.requestCode = null
        return false
    }
}