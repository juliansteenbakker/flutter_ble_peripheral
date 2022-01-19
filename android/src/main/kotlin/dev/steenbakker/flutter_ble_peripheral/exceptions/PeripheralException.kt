package dev.steenbakker.flutter_ble_peripheral.exceptions

import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import java.lang.Exception

class PeripheralException(val state: PeripheralState) : Exception(state.name)