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

typealias TransportControlRequestHandler = (CommunicationMedium, Request, Session, (()->Void)?, ((Error)->Void)?) -> Void

protocol TransportMedium {
    var medium:CommunicationMedium { get }

    init(handler: @escaping TransportControlRequestHandler)
    
    func send(message:NetworkMessage, for session:Session, completionHandler: (()->Void)?)
    func add(session:Session)
    func remove(session:Session)
    func refresh(for session:Session)

    func willEnterBackground()
    func willEnterForeground()

}


class TransportControl {
    
    private var mutex = Mutex()
    private var sessionActivity:[UUID:CommunicationActivity] = [:]
    private var transports:[TransportMedium] = []
    
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
    
    
    // create shared instance with custom bluetooth on/off
    static func shared(bluetoothEnabled:Bool = true) -> TransportControl {
        defer { sharedControlMutex.unlock() }
        sharedControlMutex.lock()
        
        guard let tc = sharedControl else {
            sharedControl = TransportControl(bluetoothEnabled: bluetoothEnabled)
            return sharedControl!
        }
        
        return tc
    }
    
    init(bluetoothEnabled:Bool = true) {        
        if bluetoothEnabled {
            transports.append(BluetoothManager(handler: handle))
        }
        transports.append(SQSManager(handler: handle))
    }
    
    func transport(for medium:CommunicationMedium) -> TransportMedium? {
        return self.transports.filter({ $0.medium == medium }).first
    }
    
    //MARK: Handle Incoming Requests
    func handle(medium:CommunicationMedium, with request:Request, for session:Session, completionHandler: (()->Void)? = nil, errorHandler: ((Error)->Void)? = nil) {
        
        // update teams if we need to
        if IdentityManager.hasTeam() && TeamUpdater.shouldCheck {
            TeamUpdater.checkForUpdate {_ in
                self.handleNoChecks(medium: medium, with: request, for: session, completionHandler: completionHandler, errorHandler: errorHandler)
            }
            return
        }
        
        self.handleNoChecks(medium: medium, with: request, for: session, completionHandler: completionHandler, errorHandler: errorHandler)
    }
    
    private func handleNoChecks(medium:CommunicationMedium, with request:Request, for session:Session, completionHandler: (()-> Void)? = nil, errorHandler: ((Error)->Void)? = nil) {
        
        do {
            // ask silo to handle the request
            try Silo.shared.handle(request: request, session: session, communicationMedium: medium, completionHandler: completionHandler)
        }
        catch {
            log("error: \(error)\nfor handling request: \(request), session id: \(session.id) -- on medium \(medium)", .error)
            errorHandler?(error)
        }
        
        mutex.lock()
        
        log("Handle Called: \(sessionActivity.count)")
        
        if let activity = sessionActivity[session.pairing.uuid] {
            activity.used(medium: medium)
            
            if activity.isInactive(on: .bluetooth) {
                log("refresh bluetooth called", .warning)
                self.transport(for: .bluetooth)?.refresh(for: session)
                activity.used(medium: .bluetooth)
            }
        }
        
        mutex.unlock()

    }
    
    //MARK: Send Outgoing Requests
    func send(_ response:Response, for session:Session, completionHandler: (()->Void)? = nil) throws {
        let sealedResponse = try response.seal(to: session.pairing)
        let message = NetworkMessage(localData: sealedResponse, header: .ciphertext)

        
        // FIXME: completion handler may get caleld multiple times
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
            let response = Response(requestID: "", endpoint: "", body: .unpair(UnpairResponse()))
            try? self.send(response, for: session)
        }
        
    }
    
    
    func willEnterBackground() {
        transports.forEach({ $0.willEnterBackground() })
    }
    
    func willEnterForeground() {
        transports.forEach({ $0.willEnterForeground() })
    }


}
