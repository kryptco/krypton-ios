//
//  Silo.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

typealias SessionLabel = String

struct NoMessageError:Error{}
struct SessionRemovedError:Error{}
struct InvalidRequestTimeError:Error{}
struct RequestPendingError:Error{}

private var sharedSilo:Silo?
class Silo {
    
    var sessionLabels:[SessionLabel:Session] = [:]
    var sessionServiceUUIDS: [CBUUID: Session] = [:]
    var mutex = Mutex()

    var bluetoothDelegate: BluetoothDelegate = BluetoothDelegate()
    var centralManager: CBCentralManager
    var sessionLastBluetoothActivity: [CBUUID:Date] = [:]
    var sessionLastNetworkActivity: [CBUUID:Date] = [:]

    var requestCache: Cache<NSData>?
    //  store requests waiting for user approval
    var pendingRequests: Cache<NSString>?

    init() {
        requestCache = try? Cache<NSData>(name: "SILO_CACHE")
        pendingRequests = try? Cache<NSString>(name: "SILO_PENDING_REQUESTS")
        centralManager = CBCentralManager(delegate: bluetoothDelegate, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "bluetoothCentralManager"])
        bluetoothDelegate.mutex.lock {
            bluetoothDelegate.silo = self
        }
    }

    func onBluetoothReceive(serviceUUID: CBUUID, message: NetworkMessage) throws {
        mutex.lock()

        guard let session = sessionServiceUUIDS[serviceUUID] else {
            log("bluetooth session not found \(serviceUUID)", .warning)
            mutex.unlock()
            return
        }
        mutex.unlock()

        guard let req = try? Request(key: session.pairing.symmetricKey, sealed: message.data) else {
            log("request from bluetooth did not parse correctly", .error)
            return
        }
        
        try handle(request: req, session: session, communicationMedium: .bluetooth)
    }

    class var shared:Silo {
        guard let ss = sharedSilo else {
            sharedSilo = Silo()
            return sharedSilo!
        }
        return ss
    }
    
    var shouldPoll:Bool = true
    
    func startPolling() {
        mutex.lock {
            sessionLabels.values.forEach({ self.startPolling(session: $0) })
        }
    }
    
    func startPolling(session:Session) {
        
        let queue = DispatchQueue(label: "read-queue-\(session.id)")
        queue.async {
            
            let pauseMutex = Mutex()
            var canPoll:Bool = true

            while canPoll {
                
                pauseMutex.lock()
                
                // check session is still active
                var isActive = false
                self.mutex.lock {
                    isActive = (self.sessionLabels[session.id] != nil)
                }
                
                guard isActive else {
                    pauseMutex.unlock()
                    return
                }
                
                // otherwise listen
                
                self.listen(to: session, completion: { (success, err) in
                    pauseMutex.unlock()
                    if let e = err, !(e is NoMessageError) {
                        log("listen error: \(e)", .error)
                        sleep(5)
                    }
                })
                
                self.mutex.lock {
                    canPoll = self.shouldPoll
                }
            }
        }

    }
    
    func listen(to: Session, completion:((Bool, Error?)->Void)?) {
        let api = API()
        
        log("listening with: \(to.id)", .warning)
        
        api.receive(to.pairing.queue) { (result) in
        
            log("finished reading from queue")
            
            // check again that the session has not responded
            var isActive = false
            self.mutex.lock {
                isActive = (self.sessionLabels[to.id] != nil)
            }
            
            guard isActive else {
                completion?(false, SessionRemovedError())
                return
            }
            
            
            switch result {
            case .message(let msgs):
                for msg in msgs {
                    
                    do {
                        let req = try Request(key: to.pairing.symmetricKey, sealed: msg.data)
                        try self.handle(request: req, session: to, communicationMedium: .sqs)
                    } catch (let e) {
                        log("error responding: \(e)", LogType.error)
                    }
                }
                
                completion?(true, nil)
                return
                
            case .sent:
                log("sent")
                completion?(true, nil)
                return

            case .failure(let e):
                log("error recieving: \(e)", LogType.error)
                completion?(false, e)
                return
            }
            
            completion?(true, NoMessageError())
        }

    }
    
    
    
    //MARK: Control
    func add(session:Session) {
        mutex.lock {
            guard sessionLabels[session.id] == nil else {
                return
            }
            
            sessionLabels[session.id] = session
            let cbuuid = session.pairing.uuid
            sessionServiceUUIDS[cbuuid] = session
            sessionLastBluetoothActivity[cbuuid] = Date()
            sessionLastNetworkActivity[cbuuid] = Date()
            bluetoothDelegate.addServiceUUID(uuid: cbuuid)

            do {
                let wrappedKeyMessage = try NetworkMessage(
                    localData: session.pairing.symmetricKey.wrap(to: session.pairing.workstationPublicKey),
                    header: .wrappedKey)

                API().send(to: session.pairing.queue, message: wrappedKeyMessage, handler: { (sendResult) in
                    switch sendResult {
                    case .sent:
                        log("success! sent response.")
                    case .failure(let e):
                        log("error sending response: \(e)", LogType.error)
                    default:
                        break
                    }
                })
                bluetoothDelegate.writeToServiceUUID(uuid: cbuuid, message: wrappedKeyMessage)

            } catch let e {
                log("error wrapping key: \(e)", .error)
                return
            }
        }
    }

    func remove(session:Session, sendUnpairResponse:Bool = true) {
        mutex.lock {
           removeLocked(session: session, sendUnpairResponse: sendUnpairResponse)
        }
    }

    func removeLocked(session:Session, sendUnpairResponse:Bool = true) {
        if sendUnpairResponse {
            let response = Response(requestID: "", endpoint: "", unpair: UnpairResponse())
            try? send(session: session, response: response)
        }
        sessionLabels.removeValue(forKey: session.id)
        let cbuuid = session.pairing.uuid
        sessionServiceUUIDS.removeValue(forKey: cbuuid)
        bluetoothDelegate.removeServiceUUID(uuid: cbuuid)
        sessionLastNetworkActivity.removeValue(forKey: cbuuid)
        sessionLastBluetoothActivity.removeValue(forKey: cbuuid)
    }


    func add(sessions:[Session]) {
        sessions.forEach({ self.add(session: $0) })
    }
    
    func stop() {
        mutex.lock {
            sessionLabels = [:]
            shouldPoll = false
        }
    }

    //MARK: Handle Logic
    enum CommunicationMedium:String {
        case bluetooth
        case remoteNotification
        case sqs
    }
    func handle(request:Request, session:Session, communicationMedium: CommunicationMedium, completionHandler: (()->Void)? = nil) throws {
        mutex.lock()
        defer { mutex.unlock() }

        switch communicationMedium {
        case .bluetooth:
            sessionLastBluetoothActivity[session.pairing.uuid] = Date()
        case .remoteNotification, .sqs:
            sessionLastNetworkActivity[session.pairing.uuid] = Date()
        }

        if let lastNetwork = sessionLastNetworkActivity[session.pairing.uuid],
            let lastBluetooth = sessionLastBluetoothActivity[session.pairing.uuid],
            lastNetwork.timeIntervalSince(lastBluetooth) > 60 {
            bluetoothDelegate.refreshServiceUUID(uuid: session.pairing.uuid)
            sessionLastBluetoothActivity[session.pairing.uuid] = Date()
        }

        let now = Date().timeIntervalSince1970
        if abs(now - Double(request.unixSeconds)) > 60 {
            throw InvalidRequestTimeError()
        }
        
        requestCache?.removeExpiredObjects()
        if  let cachedResponseData = requestCache?[request.id] as? Data,
            let json = (try JSONSerialization.jsonObject(with: cachedResponseData)) as? JSON
        {
            let response = try Response(json: json)
            try self.send(session: session, response: response, completionHandler: completionHandler)
            return
        }

        
        // logic
        
        // if signature request AND we need a user approval, 
        // then exit and wait for it
        guard   request.sign == nil || Policy.needsUserApproval == false
        else {
            pendingRequests?.removeExpiredObjects()
            if pendingRequests?.object(forKey: request.id) != nil {
                throw RequestPendingError()
            }
            pendingRequests?.setObject("", forKey: request.id, expires: .seconds(300))

            Policy.requestUserAuthorization(session: session, request: request)

            Analytics.postEvent(category: "signature", action: "requires approval", label:communicationMedium.rawValue)

            completionHandler?()
            return
        }

        if request.isNoOp() {
            return
        }

        // otherwise, continue with creating and sending the response
        let response = try responseFor(request: request, session: session, signatureAllowed: true)
        
        if response.sign != nil {
            Analytics.postEvent(category: "signature", action: "automatic approval", label: communicationMedium.rawValue)

            Policy.notifyUser(session: session, request: request)
        }
        
        try send(session: session, response: response, completionHandler: completionHandler)
    }
    
    
    func send(session:Session, response:Response, completionHandler: (()->Void)? = nil) throws {
        let sealedResponse = try response.seal(key: session.pairing.symmetricKey)
        let message = NetworkMessage(localData: sealedResponse, header: .ciphertext)

        Silo.shared.bluetoothDelegate.writeToServiceUUID(uuid: session.pairing.uuid, message: message)

        API().send(to: session.pairing.queue, message: message, handler: { (sendResult) in
            switch sendResult {
            case .sent:
                log("success! sent response.")
            case .failure(let e):
                log("error sending response: \(e)", LogType.error)
            default:
                break
            }
            completionHandler?()
        })
    }
    
    // MARK: Silo -new
    func lockResponseFor(request:Request, session:Session, signatureAllowed:Bool) throws -> Response {
        mutex.lock()
        defer { mutex.unlock() }
        return try responseFor(request: request, session: session, signatureAllowed: signatureAllowed)
    }
    
    // precondition: mutex locked
    func responseFor(request:Request, session:Session, signatureAllowed:Bool) throws -> Response {
        let requestStart = Date().timeIntervalSince1970
        defer { log("response took \(Date().timeIntervalSince1970 - requestStart) seconds") }
        var sign:SignResponse?
        var list:ListResponse?
        var me:MeResponse?

        if let _ = request.unpair {
            Analytics.postEvent(category: "device", action: "unpair", label: "request")
            SessionManager.shared.remove(session: session)
            removeLocked(session: session, sendUnpairResponse: false)
            throw SessionRemovedError()
        }
        
        if let signRequest = request.sign {
            let kp = try KeyManager.sharedInstance()
            
            var sig:String?
            var err:String?
            do {
                
                if signatureAllowed {
                    // only place where signature should occur
                    let digestData = try signRequest.digest.fromBase64()
                    sig = try kp.keyPair.sign(digest: digestData)
                    
                    dispatchAsync {
                        LogManager.shared.save(theLog: SignatureLog(session: session.id, digest: signRequest.digest, signature: sig ?? "<err>", command: signRequest.command), deviceName: session.pairing.name)
                    }
                } else {
                    err = "rejected"
                    dispatchAsync {
                        LogManager.shared.save(theLog: SignatureLog(session: session.id, digest: signRequest.digest, signature: "rejected", command: signRequest.command), deviceName: session.pairing.name)
                    }
                }

            } catch let e {
                err = "\(e)"
            }
            
            
            sign = SignResponse(sig: sig, err: err)
        }
        
        if let _ = request.list {
            list = ListResponse(peers: [])
        }
        if let _ = request.me {
            me = MeResponse(me: try KeyManager.sharedInstance().getMe())
        }
        
        let arn = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? ""
        
        var approvedUntil:Int?
        if let time = Policy.approvedUntil?.timeIntervalSince1970 {
             approvedUntil = Int(time)
        }

        let response = Response(requestID: request.id, endpoint: arn, approvedUntil: approvedUntil, sign: sign, list: list, me: me, trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
        
        let responseData = try response.jsonData() as NSData
        
        requestCache?.setObject(responseData, forKey: request.id, expires: .seconds(300))
        
        return response

    }
}
