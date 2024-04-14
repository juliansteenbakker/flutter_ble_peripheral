//
//  ServiceDescription.swift
//  flutter_ble_peripheral
//
//  Created by tiago-bacelar on 26/03/2024.
//

import Foundation
import CoreBluetooth

class ServiceDescription {
    let uuid: CBUUID
    let characteristics: [CharacteristicDescription]
    
    init(properties: Dictionary<String,Any>) {
        uuid = CBUUID(string: properties["uuid"] as! String)
        characteristics = (properties["characteristics"] as! [Dictionary<String,Any>]).map(CharacteristicDescription.init)
    }
}
