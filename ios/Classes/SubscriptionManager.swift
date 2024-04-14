//
//  SubscriptionManager.swift
//  flutter_ble_peripheral
//
//  Created by tiago-bacelar on 26/03/2024.
//

import Foundation
import CoreBluetooth

class SubscriptionManager {
    private var subscriptions: Dictionary<CBCentral, Set<CBUUID>> = Dictionary()
    
    func subscribe(device: CBCentral, characteristic: CBUUID) {
        if subscriptions[device] == nil {
            subscriptions[device] = Set()
        }
        
        subscriptions[device]!.insert(characteristic)
    }
    
    func unsubscribe(device: CBCentral, characteristic: CBUUID) {
        subscriptions[device]!.remove(characteristic)
    }
    
    func removeDeviceData(device: CBCentral) {
        subscriptions.removeValue(forKey: device)
    }
    
    func removeCharacteristicData(characteristic: CBUUID) -> [CBCentral] {
        var ans: [CBCentral] = []
        
        for (device, _) in subscriptions {
            if subscriptions[device]!.remove(characteristic) != nil {
                ans.append(device)
            }
        }
        
        return ans
    }
    
    func subscriptions(characteristic: CBUUID) -> [CBCentral] {
        return Array(subscriptions.filter{(_, sub) in sub.contains(characteristic)}.keys)
    }
    
    func hasSubscriptions(device: CBCentral) -> Bool {
        return !(subscriptions[device]?.isEmpty ?? true)
    }
}
