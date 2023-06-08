package dev.steenbakker.flutter_ble_peripheral.models

import java.util.UUID

class ServiceDescription(uuid: String, val characteristics: List<CharacteristicDescription>) {

    val uuid = UUID.fromString(uuid)

    constructor(properties: Map<String, Any>) : this(
        properties["uuid"] as String,
        (properties["characteristics"] as List<Map<String,Any>>).map{CharacteristicDescription(it)}
    )
}