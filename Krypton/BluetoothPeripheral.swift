//
//  Bluetooth.swift
//  Krypton
//
//  Created by Kevin King on 9/12/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreBluetooth
import AwesomeCache

class BluetoothPeripheralDelegate : NSObject, CBPeripheralManagerDelegate {
    var peripheralManager:CBPeripheralManager?
    var onReceive:BluetoothOnReceiveCallback?

    var allServiceUUIDS : Set<CBUUID> = Set()
    var addedServiceUUIDS: Set<CBUUID> = Set()
    var serviceUUIDAdvertisementOrder : [CBUUID] = []
    var advertisedServiceUUID : CBUUID? = nil
    var cbservicesByUUID: [CBUUID: CBMutableService] = [:]
    var cbcharacteristicsByUUID: [CBUUID: CBMutableCharacteristic] = [:]
    var subscribedCentralsByServiceUUID: [CBUUID: Set<CBCentral>] = [:]
    var rotateEpoch: Int = 0

    //  incoming buffers
    var characteristicMessageBuffersAndLastSplitNumber: [CBCharacteristic: (Data, UInt8)] = [:]

    //  outgoing queue
    var queuedSplitsWithServiceUUID: [(CBUUID, Data)] = []
    var lastOutgoingMessageAndServiceUUID : (NetworkMessage, CBUUID)?

    let mutex : Mutex = Mutex()
    let queue : DispatchQueue
    var readyToUpdateSubscribers = true

    // Constants
    static let krsshCharUUID = CBUUID(string: "20F53E48-C08D-423A-B2C2-1C797889AF24")
    static let refreshByte = UInt8(0)
    static let pingByte = UInt8(1)
    static let pingMsg = Data(bytes: [pingByte])

    init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
        log("init bluetooth")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        self.peripheralManager = peripheral
        log("\(dict)")
        //  Note: restoring CBPeripheralManager services only works on iOS 11.2+ (it was buggy in previous iOS11 versions)
        guard let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] else {
            return
        }
        for service in services {
            log("restoring service \(service)")
            allServiceUUIDS.insert(service.uuid)
            addedServiceUUIDS.insert(service.uuid)
            cbservicesByUUID[service.uuid] = service
            guard let characteristics = service.characteristics else {
                continue
            }
            for characteristic in characteristics {
                guard characteristic.uuid == BluetoothPeripheralDelegate.krsshCharUUID else {
                    continue
                }
                log("restoring characteristic \(characteristic)")
                guard let mutableCharacteristic = characteristic as? CBMutableCharacteristic else {
                    continue
                }
                cbcharacteristicsByUUID[service.uuid] = mutableCharacteristic
                guard let newSubscribedCentrals = mutableCharacteristic.subscribedCentrals else {
                    continue
                }
                var allSubscribedCentrals = subscribedCentralsByServiceUUID[service.uuid] ?? Set()
                for subscribedCentral in newSubscribedCentrals {
                    log("restoring central \(subscribedCentral)")
                    allSubscribedCentrals.insert(subscribedCentral)
                }
                subscribedCentralsByServiceUUID[service.uuid] = allSubscribedCentrals
            }
        }
        self.advertiseLogic()
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            peripheral.removeAllServices()
            log("powered on")
            mutex.lock {
                readyToUpdateSubscribers = true
                serviceUUIDAdvertisementOrder = Array(allServiceUUIDS)
            }
            break
        default:
            log("state: \(peripheral.state.rawValue)")
            break
        }
        queue.async { self.advertiseLogic() }
    }

    func advertiseLogic() {
        guard let peripheralManager = peripheralManager else {
            log("peripheralManager nil", .error)
            return
        }
        if case .poweredOn = peripheralManager.state {
            if addedServiceUUIDS != allServiceUUIDS {
                peripheralManager.stopAdvertising()
                if let nextService = allServiceUUIDS.subtracting(addedServiceUUIDS).first {
                    let options: CBCharacteristicProperties = [.write, .read, .notify, .writeWithoutResponse]
                    let permissions: CBAttributePermissions = [.readable, .writeable]
                    let characteristic = CBMutableCharacteristic(type: BluetoothPeripheralDelegate.krsshCharUUID, properties: options, value: nil, permissions: permissions)
                    let service = CBMutableService(type: nextService, primary: true)
                    service.characteristics = [characteristic]
                    peripheralManager.add(service)
                    addedServiceUUIDS.insert(nextService)
                    log("adding service \(nextService) to gatt database")
                    cbservicesByUUID[nextService] = service
                    cbcharacteristicsByUUID[nextService] = characteristic
                }
            } else {
                rotateAdvertisement(peripheralManager, epoch: rotateEpoch)
            }
        } else {
            addedServiceUUIDS.removeAll()
            advertisedServiceUUID = nil
            cbservicesByUUID = [:]
            cbcharacteristicsByUUID = [:]
            subscribedCentralsByServiceUUID = [:]
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        log("did add service \(service.uuid)", .debug)
        advertiseLogic()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let e = error {
            log("error starting advertising, error: \(e)", .error)
        } else {
            log("did start advertising", .debug)
        }
        let delay = DispatchTime.now() + Double(Int64(2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        let rotateEpoch = self.rotateEpoch
        queue.asyncAfter(deadline: delay, execute: {
            self.rotateAdvertisement(peripheral, epoch: rotateEpoch)
        })
    }

    func rotateAdvertisement(_ peripheral: CBPeripheralManager, epoch: Int) {
        guard rotateEpoch == epoch else {
            return
        }
        rotateEpoch += 1
        
        let localServiceUUIDAdvertisementOrder = serviceUUIDAdvertisementOrder
        
        if let currentAdvertisement = advertisedServiceUUID,
            let currentIndex = localServiceUUIDAdvertisementOrder.index(of: currentAdvertisement) {
            let nextIndex = (currentIndex + 1) % localServiceUUIDAdvertisementOrder.count
            advertisedServiceUUID = localServiceUUIDAdvertisementOrder[nextIndex]
        } else {
            advertisedServiceUUID = localServiceUUIDAdvertisementOrder.first
        }
        peripheral.stopAdvertising()
        if let currentAdvertisement = advertisedServiceUUID {
            peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [currentAdvertisement]])
            log("advertising \(currentAdvertisement.uuidString)", .debug)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        mutex.lock()
        defer { mutex.unlock() }
        log("central \(central.identifier) subscribed")
        let serviceUUID = characteristic.service.uuid
        var centrals = subscribedCentralsByServiceUUID[serviceUUID] ?? Set()
        centrals.insert(central)
        subscribedCentralsByServiceUUID[serviceUUID] = centrals
        if let (message, lastServiceUUID) = lastOutgoingMessageAndServiceUUID,
            serviceUUID == lastServiceUUID {
            writeToServiceUUIDLocked(uuid: lastServiceUUID, message: message)
        }
        serviceUUIDAdvertisementOrder = Array(allServiceUUIDS.subtracting(subscribedCentralsByServiceUUID.keys))
        advertiseLogic()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        log("central \(central.identifier) unsubscribed")
        let serviceUUID = characteristic.service.uuid
        var centrals = subscribedCentralsByServiceUUID[serviceUUID] ?? Set()
        centrals.remove(central)
        subscribedCentralsByServiceUUID.removeValue(forKey: serviceUUID)
        serviceUUIDAdvertisementOrder = Array(allServiceUUIDS.subtracting(subscribedCentralsByServiceUUID.keys))
        advertiseLogic()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log("received write", .debug)
        for write in requests {
            if let data = write.value {
                mutex.lock {
                    self.onUpdateCharacteristicValueLocked(characteristic: write.characteristic, data: data)
                }
            }
            peripheral.respond(to: write, withResult: .success)
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        mutex.lock {
            readyToUpdateSubscribers = true
            processWriteQueueLocked()
        }
    }

    func writeToServiceUUID(uuid: CBUUID, message: NetworkMessage) {
        mutex.lock()
        defer { mutex.unlock() }
        writeToServiceUUIDLocked(uuid: uuid, message: message)
    }

    func writeToServiceUUIDLocked(uuid: CBUUID, message: NetworkMessage) {
        lastOutgoingMessageAndServiceUUID = (message, uuid)
        let data = message.networkFormat()

        do {
            let messageBlocks = try splitMessageForBluetooth(message: data, mtu: UInt(100))
            for block in messageBlocks {
                writeToServiceUUIDRawLocked(uuid: uuid, data: block)
            }
            log("sent BT response", .debug)
        } catch let e {
            log("bluetooth message split failed: \(e)", .error)
        }
    }

    func writeToServiceUUIDRawLocked(uuid: CBUUID, data: Data) {
        queuedSplitsWithServiceUUID.append((uuid, data))
        processWriteQueueLocked()
    }

    func processWriteQueueLocked() {
        guard let peripheralManager = peripheralManager,
            case .poweredOn = peripheralManager.state else {
                return
        }
        while readyToUpdateSubscribers {
            guard let (uuid, data) = queuedSplitsWithServiceUUID.first else {
                return
            }
            guard let subscribedCentrals = subscribedCentralsByServiceUUID[uuid],
                let characteristic = cbcharacteristicsByUUID[uuid] else {
                    queuedSplitsWithServiceUUID.removeFirst()
                    continue
            }
            readyToUpdateSubscribers = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: Array(subscribedCentrals))
            if readyToUpdateSubscribers {
                queuedSplitsWithServiceUUID.removeFirst()
            }
        }
    }

    func addServiceUUID(uuid: CBUUID) {
        mutex.lock()
        defer { mutex.unlock() }

        if allServiceUUIDS.contains(uuid) {
            log("already had uuid \(uuid.uuidString)")
            return
        }

        log("add uuid \(uuid.uuidString)")
        allServiceUUIDS.insert(uuid)
        serviceUUIDAdvertisementOrder = Array(allServiceUUIDS)
        queue.async{ self.advertiseLogic() }
    }

    func removeServiceUUID(uuid: CBUUID) {
        mutex.lock()
        defer { mutex.unlock() }
        removeServiceUUIDLocked(uuid: uuid)
        queue.async{ self.advertiseLogic() }
    }

    func removeServiceUUIDLocked(uuid: CBUUID) {
        if !allServiceUUIDS.contains(uuid) {
            log("didn't have uuid \(uuid.uuidString) in allServiceUUIDS", .error)
        } else {
            log("remove uuid \(uuid.uuidString)")
        }
        allServiceUUIDS.remove(uuid)
        serviceUUIDAdvertisementOrder = Array(allServiceUUIDS)
        if let service = cbservicesByUUID[uuid] {
            peripheralManager?.remove(service)
        }
        cbservicesByUUID.removeValue(forKey: uuid)
        addedServiceUUIDS.remove(uuid)
    }

    //  precondition: mutex locked
    func onUpdateCharacteristicValueLocked(characteristic: CBCharacteristic, data: Data) {
        if data.count == 0 {
            log("empty data", .error)
            return
        }

        let n = data[0]
        let data = data.subdata(in: 1..<data.count)
        
        let bufferAndLastN = characteristicMessageBuffersAndLastSplitNumber[characteristic]
        
        if var buffer = bufferAndLastN?.0, let lastN = bufferAndLastN?.1, lastN > 0, (n == lastN - 1) {
            buffer.append(data)
            characteristicMessageBuffersAndLastSplitNumber[characteristic] = (buffer, n)
        } else {
            characteristicMessageBuffersAndLastSplitNumber[characteristic] = (data, n)
        }
        
        if n == 0 {
            // buffer complete
            if let (fullBuffer, _) = characteristicMessageBuffersAndLastSplitNumber.removeValue(forKey: characteristic) {
                log("reconstructed full message of length \(fullBuffer.count)", .debug)
                
                mutex.unlock()
                do {
                    let message = try NetworkMessage(networkData: fullBuffer)
                    try self.onReceive?(characteristic.service.uuid, message)
                } catch (let e) {
                    log("error processing bluetooth message: \(e)", .error)
                }
                mutex.lock()

            }
        }
    }

}
