//
//  NotificationManager.swift
//  flutter_ble_peripheral
//
//  Created by tiago-bacelar on 10/04/2024.
//

import Foundation
import CoreBluetooth

class Node {
    let data: Data
    let char: CBMutableCharacteristic
    let result: FlutterResult?
    
    var next: Node?
    
    init(_ data: Data, _ char: CBMutableCharacteristic, _ result: FlutterResult?) {
        self.data = data
        self.char = char
        self.result = result
    }
}

struct Queue {
    var first: Node?
    var last: Node?
    
    mutating func enqueue(_ data: Data, _ char: CBMutableCharacteristic, _ result: FlutterResult?) {
        let node = Node(data, char, result)
        if let l = last {
            l.next = node
            last = node
        } else {
            first = node
            last = node
        }
    }
    
    mutating func dequeue() -> (Data, CBMutableCharacteristic, FlutterResult?) {
        let f = first!
        first = f.next
        if first == nil {
            last = nil
        }
        return (f.data, f.char, f.result)
    }
    
    var isEmpty: Bool { first == nil }
    
    var head: (Data, CBMutableCharacteristic, FlutterResult?) { (first!.data, first!.char, first!.result) }
}

class NotificationManager {
    let peripheralManager: CBPeripheralManager
    var queue: Queue = Queue()
    
    init(_ peripheralManager: CBPeripheralManager) {
        self.peripheralManager = peripheralManager
    }
    
    func sendNotification(_ data: Data, _ char: CBMutableCharacteristic, _ result: FlutterResult?) {
        if queue.isEmpty && peripheralManager.updateValue(data, for: char, onSubscribedCentrals: nil) {
            result?(nil)
        } else {
            queue.enqueue(data, char, result)
        }
    }
    
    func resume() {
        while !queue.isEmpty {
            let (data, char, result) = queue.head
            
            if peripheralManager.updateValue(data, for: char, onSubscribedCentrals: nil) {
                _ = queue.dequeue()
                result?(nil)
            } else {
                return
            }
        }
    }
}
