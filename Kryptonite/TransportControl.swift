//
//  TransportControl.swift
//  Kryptonite
//
//  Created by Alex Grinman on 3/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import CoreBluetooth

struct SessionRemovedError:Error{}

typealias TransportControlRequestHandler = (CommunicationMedium, Request, Session, (()->Void)? ) throws -> Void

protocol TransportMedium {
    var medium:CommunicationMedium { get }

    init(handler: @escaping TransportControlRequestHandler)
    
    func send(message:NetworkMessage, for session:Session, completionHandler: (()->Void)?)
    func add(session:Session)
    func remove(session:Session)
    func refresh(for session:Session)

    func willEnterBackground()
}


class TransportControl {
    
    var mutex = Mutex()
    var sessionActivity:[UUID:CommunicationActivity] = [:]
    var transports:[TransportMedium] = []
    
    private static var sharedControlMutex = Mutex()
    private static var sharedControl:TransportControl?
    
    static var shared:TransportControl {
        defer { sharedControlMutex.unlock() }
        sharedControlMutex.lock()
        
        guard let tc = sharedControl else {
            sharedControl = TransportControl()
            return sharedControl!
        }
        
        return tc
    }
    
    init() {
        transports = [ BluetoothManager(handler: handle), SQSManager(handler: handle) ]
    }
    
    func transport(for medium:CommunicationMedium) -> TransportMedium? {
        return self.transports.filter({ $0.medium == medium }).first
    }
    
    //MARK: Handle Incoming Requests
    func handle(medium:CommunicationMedium, with request:Request, for session:Session, completionHandler: (()->Void)? = nil) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        if let activity = sessionActivity[session.pairing.uuid] {
            activity.used(medium: medium)
            
            if activity.isInactive(on: .bluetooth) {
                log("refresh bluetooth called", .warning)
                self.transport(for: .bluetooth)?.refresh(for: session)
                activity.used(medium: .bluetooth)
            }
        }

        try Silo.shared.handle(request: request, session: session, communicationMedium: medium, completionHandler: completionHandler)
    }
    
    //MARK: Send Outgoing Requests
    func send(_ response:Response, for session:Session, completionHandler: (()->Void)? = nil) throws {
        let sealedResponse = try response.seal(to: session.pairing)
        let message = NetworkMessage(localData: sealedResponse, header: .ciphertext)

        transports.forEach({ $0.send(message: message, for: session, completionHandler: completionHandler) })
    }

    //MARK: Pairing Completion
    func waitForPairing(session:Session, timeout:TimeInterval = 10.0) -> Bool {
        let startTime = Date()
        let uuid = session.pairing.uuid
        
        while true {
            mutex.lock()
            if let everActive = sessionActivity[uuid]?.everActive(), everActive {
                mutex.unlock()
                break
            }
            mutex.unlock()
            usleep(250*1000)
            guard abs(Date().timeIntervalSince(startTime)) < timeout else {
                return false
            }
        }
        return true
    }
    
    
    //MARK: Session Management
    func add(sessions:[Session]) {
        sessions.forEach({ self.add(session: $0) })
    }

    func add(session:Session, newPairing:Bool = false) {
        mutex.lock {
            sessionActivity[session.pairing.uuid] = CommunicationActivity()
        }
        
        transports.forEach({ $0.add(session: session) })
    
        if newPairing {
            do {
                let wrappedKeyMessage = try NetworkMessage(
                    localData: session.pairing.keyPair.publicKey.wrap(to: session.pairing.workstationPublicKey),
                    header: .wrappedPublicKey)
                
                transports.forEach({
                    $0.send(message: wrappedKeyMessage, for: session, completionHandler: nil)
                })
            } catch let e {
                log("error wrapping key: \(e)", .error)
                return
            }
        }
    }
    
    func remove(session:Session, sendUnpairResponse:Bool = true) {
        mutex.lock {
            transports.forEach({ $0.remove(session: session) })
            sessionActivity.removeValue(forKey: session.pairing.uuid)
        }
        
        if sendUnpairResponse {
            let response = Response(requestID: "", endpoint: "", unpair: UnpairResponse())
            try? self.send(response, for: session)
        }
        
    }
    
    
    func willEnterBackground() {
        transports.forEach({ $0.willEnterBackground() })
    }

}
