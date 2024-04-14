//
//  CallbackManager.swift
//  flutter_ble_peripheral
//
//  Created by tiago-bacelar on 10/04/2024.
//

import Foundation

class Unit : Equatable, Hashable {
    static let instance: Unit = Unit()
    
    private init() {}
    
    static func ==(lhs: Unit, rhs: Unit) -> Bool {
        return true
    }
    
    func hash(into hasher: inout Hasher) {}
}

class CallbackManager<K: Hashable,A> {
    private var callbacks: Dictionary<K,(A)->()> = Dictionary()
    
    func addCallback(_ key: K, _ callback: @escaping (A) -> ()) -> Bool {
        if callbacks[key] == nil {
            callbacks[key] = callback
            return true
        } else {
            return false
        }
    }
    
    func completeCallback(_ key: K, _ value: A) {
        if let c = callbacks.removeValue(forKey: key) {
            c(value)
        } else {
            print("[flutter_ble_peripheral] Attempt to call unregistered callback (key: \(key), value: \(value)")
        }
    }
    
    func cancelCallback(_ key: K) {
        callbacks.removeValue(forKey: key)
    }
}
