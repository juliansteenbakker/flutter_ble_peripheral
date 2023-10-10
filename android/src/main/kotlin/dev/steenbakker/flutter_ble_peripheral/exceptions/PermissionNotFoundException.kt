package dev.steenbakker.flutter_ble_peripheral.exceptions

import dev.steenbakker.flutter_ble_peripheral.models.PeripheralState
import java.lang.Exception

class PermissionNotFoundException(
    val permission: String
) : PeripheralException(PeripheralState.unauthorized) {
    override val message: String
        get() = "${super.message}: missing permission $permission"
}
