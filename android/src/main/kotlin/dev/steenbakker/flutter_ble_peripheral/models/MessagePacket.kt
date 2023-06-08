package dev.steenbakker.flutter_ble_peripheral.models

import java.util.UUID

class MessagePacket(val characteristic : UUID, val value : ByteArray) {

    fun toMap() : Map<String,Any> {
        return mapOf(
            "characteristic" to characteristic.toString(),
            "value" to value
        )
    }
}