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
    
    // TODO: add service data
    static let serviceUUID: String = "8ebdb2f3-7817-45c9-95c5-c5e9031aaa47"
    static let txCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D4"
    static let rxCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D5"
    
    init(uuid: String?, localName: String?) {
        self.uuid = uuid //uuid;
        self.localName = localName
    }
}
