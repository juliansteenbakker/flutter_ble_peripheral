/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */


import Foundation
import CoreBluetooth
import CoreLocation

class FlutterBlePeripheralManager : NSObject {
    ///After this time, a device is considered disconencted (in milliseconds)
    static let interactionTimeout = 5000
    
    let stateHandler: StateChangedHandler
    let dataHandler: DataReceivedHandler
    let mtuHandler: MtuChangedHandler
    
    var peripheralManager: CBPeripheralManager!
    var services: Dictionary<CBUUID, CBMutableService> = Dictionary()
    var characteristics: Dictionary<CBUUID,(CBMutableCharacteristic,Data)> = Dictionary()
    var interactionTimers: Dictionary<CBCentral, DispatchWorkItem> = Dictionary()
    var devices: Set<CBCentral> = Set()
    
    let subscriptionManager: SubscriptionManager = SubscriptionManager()
    var notificationManager: NotificationManager!
    let advertisingCallbacks: CallbackManager<Unit,Error?> = CallbackManager()
    let addServiceCallbacks: CallbackManager<CBUUID,Error?> = CallbackManager()
    
    init(stateHandler: StateChangedHandler, mtuHandler: MtuChangedHandler, dataHandler: DataReceivedHandler) {
        self.stateHandler = stateHandler
        self.mtuHandler = mtuHandler
        self.dataHandler = dataHandler
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil) //TODO: restore options? also, include UIBackgroundModes in plist (https://cloudcity.io/blog/2016/09/14/zero-to-ble-on-ios-part-three)
        notificationManager = NotificationManager(peripheralManager)
    }
    
    func hasPermission() -> Int {
        if #available(iOS 13.0, *) {
            let authorization: CBManagerAuthorization
            if #available(iOS 13.1, *) {
                authorization = CBPeripheralManager.authorization
            } else {
                authorization = peripheralManager.authorization
            }
            
            switch authorization {
                case .allowedAlways:    return 0
                case .denied:           return 2
                case .notDetermined:    return 1
                case .restricted:       return 4
                @unknown default:       return 3
            }
        } else {
            return 0;
        }
    }
    
    func start(advertiseData: PeripheralData, result: @escaping FlutterResult) {
        var dataToBeAdvertised: [String: Any]! = [:]
        if (advertiseData.uuid != nil) {
            dataToBeAdvertised[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: advertiseData.uuid!)]
        }
        
        if (advertiseData.localName != nil) {
            dataToBeAdvertised[CBAdvertisementDataLocalNameKey] = advertiseData.localName
        }
        
        if advertisingCallbacks.addCallback(Unit.instance, { [weak self] error in
            if let err = error {
                result(FlutterError(code: "UknownError", message: err.localizedDescription, details: nil))
            } else {
                self!.stateHandler.advertising = true
                self!.stateHandler.publishPeripheralState()
                result(nil)
            }
        }) {
            peripheralManager.startAdvertising(dataToBeAdvertised)
        } else {
            result(FlutterError(code: "DuplicatedOperation", message: "Duplicated call to start without waiting for response", details: nil))
        }
    }
    
    func stop(result: FlutterResult? = nil) {
        peripheralManager.stopAdvertising()
        advertisingCallbacks.cancelCallback(Unit.instance)
        stateHandler.advertising = false
        stateHandler.publishPeripheralState()
        result?(nil)
    }

    func addService(description: ServiceDescription, result: @escaping FlutterResult) {
        if let _ = services[description.uuid] {
            return result(false)
        }
        
        for char in description.characteristics {
            if let _ = characteristics[char.uuid] {
                return result(FlutterError(code: "InvalidCharacteristicUUID", message: "Characteristic uuid already exists", details: char.uuid.uuidString))
            }
        }
        
        let service = CBMutableService(type: description.uuid, primary: true)
        let chars = description.characteristics.map{
            let ans = CBMutableCharacteristic(type: $0.uuid, properties: $0.properties(), value: nil, permissions: $0.permissions())
            characteristics[$0.uuid] = (ans, $0.value)
            
            return ans
        }
        service.characteristics = chars
        
        if addServiceCallbacks.addCallback(service.uuid, {[weak self] error in
            if let err = error {
                result(FlutterError(code: "UnknownError", message: err.localizedDescription, details: nil))
            } else {
                self!.services[service.uuid] = service
                result(true)
            }
        }) {
            peripheralManager.add(service)
        } else {
            result(false)
        }
    }
    
    func removeService(uuid: CBUUID) -> Bool {
        if let s = services.removeValue(forKey: uuid) {
            var subs = Set<CBCentral>()
            
            if let chars = s.characteristics {
                for char in chars {
                    characteristics.removeValue(forKey: char.uuid)
                    subs.formUnion(subscriptionManager.removeCharacteristicData(characteristic: char.uuid))
                }
            }
            
            peripheralManager.remove(s)
            for device in subs {
                checkConnection(device)
            }
            
            return true
        }
        return false
    }
    
    func read(characteristic: CBUUID) -> Data? {
        return characteristics[characteristic]?.1
    }
    
    func write(characteristic: CBUUID, data: Data, offset: Int = 0, result: FlutterResult? = nil) {
        if characteristics[characteristic] == nil {
            result?(FlutterError(code: "InvalidCharacteristicUUID", message: "Characteristic uuid doesn't exist", details: characteristic.uuidString))
            return
        } else {
            let (char, _) = characteristics[characteristic]!
            let currentSize = characteristics[characteristic]!.1.count
            
            if offset < currentSize {
                characteristics[characteristic]!.1 = characteristics[characteristic]!.1.prefix(offset) + data
            } else {
                characteristics[characteristic]!.1 += Data(count: offset - currentSize) + data
            }
            
            dataHandler.publishData(characteristic: characteristic, value: characteristics[characteristic]!.1)
            
            notificationManager.sendNotification(characteristics[characteristic]!.1, char, result)
        }
    }
    
    
    /*func disconnect() {
        for d in devices {
            onDisconnect(d)
        }
    }*/
    
    ///Whenever a device interacts with the gatt server, its cooldown for disconnection is reset
    func onInteraction(_ device: CBCentral) {
        devices.insert(device)
        mtuHandler.publishMtu(mtu: device.maximumUpdateValueLength)
        
        let timer = DispatchWorkItem(block: { [weak self] in
            self?.interactionTimers.removeValue(forKey: device)
            self?.checkConnection(device)
        })
        
        interactionTimers[device]?.cancel()
        interactionTimers[device] = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(FlutterBlePeripheralManager.interactionTimeout), execute: timer)
        
        stateHandler.connected = true
        stateHandler.publishPeripheralState()
    }
    
    ///Checks if a device is still conected. If not, calls onDisconnect
    func checkConnection(_ device: CBCentral) {
        if interactionTimers[device] == nil && !subscriptionManager.hasSubscriptions(device: device) {
            onDisconnect(device)
        }
    }
    
    ///Called when a device hasn't interacted with the server in [interactionTimeout] and isn't subscribed to any characteristic
    private func onDisconnect(_ device: CBCentral) {
        subscriptionManager.removeDeviceData(device: device)
        interactionTimers.removeValue(forKey: device)?.cancel()
        devices.remove(device)
        
        if devices.isEmpty {
            stateHandler.connected = false
            stateHandler.publishPeripheralState()
        }
    }
}
