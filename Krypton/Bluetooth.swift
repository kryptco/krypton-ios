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


class BluetoothManager:TransportMedium {

    let queue: DispatchQueue
    var handler:TransportControlRequestHandler

    var peripheralManager:CBPeripheralManager? = nil
    var bluetoothDelegate:BluetoothPeripheralDelegate? = nil
    var sessionServiceUUIDS: [String: Session] = [:]
    var queuedMessages : [(Session, NetworkMessage)] = []
    var mutex = Mutex()
    var hasPromptedForBluetoothPermission = false
    
    var medium:CommunicationMedium {
        return .bluetooth
    }
    
    required init(handler: @escaping TransportControlRequestHandler) {
        self.handler = handler
        self.queue = DispatchQueue.global()
    }

    private lazy var spawnBluetoothInitOnce : () = {
        dispatchAsync {
            while !self.tryInitBluetooth() {
                sleep(1)
            }
        }
    }()

    //  check for background bluetooth authorization and initialize bluetooth if enabled
    //  if bluetooth is not powered on, prompt user to do so once per app launch
    func tryInitBluetooth() -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        log("\(CBPeripheralManager.authorizationStatus())")
        guard case .authorized = CBPeripheralManager.authorizationStatus() else {
            //  prompt for user to turn bluetooth on once per app launch
            log("bluetooth authorization failed: \(CBPeripheralManager.authorizationStatus())")
            if !hasPromptedForBluetoothPermission {
                hasPromptedForBluetoothPermission = true
                let _ = CBPeripheralManager()
            }
            return false
        }
        self.bluetoothDelegate = BluetoothPeripheralDelegate(queue: queue)

        var cbPeripheralManagerOptions : [String: String]? = nil
        //  Note: restoring CBPeripheralManager services only works on iOS 11.2+ (it was buggy in previous iOS11 versions)
        if #available(iOS 11.2, *) {
            cbPeripheralManagerOptions = [CBPeripheralManagerOptionRestoreIdentifierKey: "bluetoothPeripheralManager"]
        }
        self.peripheralManager = CBPeripheralManager(delegate: bluetoothDelegate, queue: queue, options: cbPeripheralManagerOptions)

        self.bluetoothDelegate?.peripheralManager = self.peripheralManager
        self.bluetoothDelegate?.onReceive = onBluetoothReceive
        for session in sessionServiceUUIDS.values {
            addLocked(session: session)
        }
        for (session, message) in queuedMessages {
            sendLocked(message: message, for: session, completionHandler: nil)
        }
        queuedMessages.removeAll()
        return true
    }
    
    //MARK: Transport
    
    func send(message:NetworkMessage, for session:Session, completionHandler: (()->Void)?) {
        //TODO: bluetooth completion
        mutex.lock()
        defer { mutex.unlock() }
        sendLocked(message: message, for: session, completionHandler: completionHandler)
    }

    private func sendLocked(message:NetworkMessage, for session:Session, completionHandler: (()->Void)?) {
        //TODO: bluetooth completion
        guard let delegate = bluetoothDelegate else {
            queuedMessages.append((session, message))
            while queuedMessages.count > 5 {
                let _ = queuedMessages.dropFirst()
            }
            return
        }
        delegate.writeToServiceUUID(uuid: CBUUID(nsuuid: session.pairing.uuid), message: message)
    }

    func add(session:Session) {
        let _ = self.spawnBluetoothInitOnce
        mutex.lock {
            addLocked(session: session)
        }
    }
    private func addLocked(session:Session) {
        let uuid = session.pairing.uuid
        sessionServiceUUIDS[uuid.uuidString] = session
        bluetoothDelegate?.addServiceUUID(uuid: CBUUID(nsuuid: uuid))
    }
    func remove(session:Session) {
        mutex.lock {
            let uuid = session.pairing.uuid
            sessionServiceUUIDS.removeValue(forKey: uuid.uuidString)
            bluetoothDelegate?.removeServiceUUID(uuid: CBUUID(nsuuid: uuid))
        }
    }
    func willEnterBackground() {
        // do nothing
    }
    func willEnterForeground() {
        // do nothing
    }

    func refresh(for session:Session) { }

    
    // MARK: Bluetooth
    func onBluetoothReceive(serviceUUID: CBUUID, message: NetworkMessage) throws {
        mutex.lock()
        
        guard let session = sessionServiceUUIDS[serviceUUID.uuidString] else {
            log("bluetooth session not found \(serviceUUID)", .warning)
            mutex.unlock()
            return
        }
        mutex.unlock()
        
        guard let req = try? Request(from: session.pairing, sealed: message.data) else {
            log("request from bluetooth did not parse correctly", .error)
            return
        }
        
        try self.handler(self.medium, req, session, nil)
    }

}


typealias BluetoothOnReceiveCallback = (CBUUID, NetworkMessage) throws -> Void

struct BluetoothMessageTooLong : Error {
    var messageLength : Int
    var mtu : Int
}

/*
 *  Bluetooth packet protocol: 
 *  1-byte message = control message:
 *      0: disconnect from workstation
 *      1: ping/pong
 *  multi-byte message = data
 *      first byte of message indicates number of
 *      remaining packets. Packets must be <= mtu in length.
 */
func splitMessageForBluetooth(message: Data, mtu: UInt) throws -> [Data] {
    let msgBlockSize = mtu - 1;
    let (intN, overflow) = UInt(message.count).dividedReportingOverflow(by: msgBlockSize)
    if overflow || intN > 255 {
        throw BluetoothMessageTooLong(messageLength: message.count, mtu: Int(mtu))
    }
    var blocks : [Data] = []
    let n: UInt8 = UInt8(intN)
    var offset = Int(0)
    for n in (0...n).reversed() {
        var block = Data()
        var inoutN = n
        block.append(&inoutN, count: 1)
        let endIndex = min(message.count, offset + Int(msgBlockSize))
        block.append(message.subdata(in: offset..<endIndex))

        blocks.append(block)
        offset += Int(msgBlockSize)
    }
    return blocks
}

