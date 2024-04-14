//
//  CharacteristicDescription.swift
//  Runner
//
//  Created by tiago-bacelar on 26/03/2024.
//

import Foundation
import CoreBluetooth

class CharacteristicDescription {
    let uuid: CBUUID
    let value: Data
    let read: Bool
    let write: Bool
    let writeNR: Bool
    let notify: Bool
    let indicate: Bool
    
    init(properties: Dictionary<String,Any>) {
        uuid = CBUUID(string: properties["uuid"] as! String)
        value = (properties["value"] as! FlutterStandardTypedData).data
        read = properties["read"] as! Bool
        write = properties["write"] as! Bool
        writeNR = properties["writeNR"] as! Bool
        notify = properties["notify"] as! Bool
        indicate = properties["indicate"] as! Bool
    }
    
    func properties() -> CBCharacteristicProperties {
        var ans = CBCharacteristicProperties()
        if read { ans.insert(.read) }
        if write { ans.insert(.write) }
        if writeNR { ans.insert(.writeWithoutResponse) }
        if notify { ans.insert(.notify) }
        if indicate { ans.insert(.indicate) }
        return ans
    }
    
    func permissions() -> CBAttributePermissions {
        var ans = CBAttributePermissions()
        if read { ans.insert(.readable) }
        if write || writeNR { ans.insert(.writeable) }
        return ans
    }
}
