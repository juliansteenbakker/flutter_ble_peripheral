//
//  PeripheralData.swift
//  flutter_ble_peripheral
//
//  Created by Julian Steenbakker on 06/12/2021.
//

import Foundation

class PeripheralData {
    var uuid: String?
    var localName: String?     //CBAdvertisementDataLocalNameKey
    
    init(properties: Dictionary<String, Any>) {
        self.uuid = properties["serviceUuid"] as? String
        self.localName = properties["localName"] as? String
    }
}
