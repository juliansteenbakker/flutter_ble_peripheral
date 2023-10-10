package dev.steenbakker.flutter_ble_peripheral.exceptions

import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import java.lang.Exception

open class PeripheralException(val state: PeripheralState) : Exception(state.name) {
    override val message: String
        get() = "Invalid state ${state.name}"
}