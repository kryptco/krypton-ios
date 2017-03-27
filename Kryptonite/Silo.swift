//
//  Silo.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreBluetooth
import JSON
import AwesomeCache

typealias SessionLabel = String

struct NoMessageError:Error{}
struct SessionRemovedError:Error{}
struct InvalidRequestTimeError:Error{}
struct RequestPendingError:Error{}

struct SiloCacheCreationError:Error{}

typealias CacheKey = String
extension CacheKey {
    init(_ session:Session, _ request:Request) {
        self = "\(session.id)_\(request.id)"
    }
}


class Silo {
    
    var sessionLabels:[SessionLabel:Session] = [:]
    var sessionServiceUUIDS: [String: Session] = [:]
    var mutex = Mutex()

    var bluetoothDelegate:BluetoothDelegate?
    var centralManager:CBCentralManager?
    var sessionActivity:[CBUUID:CommunicationActivity] = [:]

    var requestCache: Cache<NSData>?
    //  store requests waiting for user approval
    var pendingRequests: Cache<NSString>?
    
    // singelton
    private static var sharedSilo:Silo?
    

    init(bluetoothEnabled:Bool = true) {
        requestCache = try? Cache<NSData>(name: "silo_cache", directory: sharedDirectory)
        pendingRequests = try? Cache<NSString>(name: "silo_pending_requests", directory: sharedDirectory)
        
        if bluetoothEnabled {
            bluetoothDelegate = BluetoothDelegate()
            centralManager = CBCentralManager(delegate: bluetoothDelegate, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "bluetoothCentralManager"])
            bluetoothDelegate?.mutex.lock {
                bluetoothDelegate?.silo = self
            }

        }
    }
    
    lazy var sharedDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID)?.appendingPathComponent("cache")
    }()

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
            sessionLabels.values.forEach({ self.poll(session: $0) })
        }
    }
    
    func poll(session:Session) {
        
        let queue = DispatchQueue(label: "read-queue-\(session.id)")
        queue.async {
            var canPoll:Bool = true
            var isActive = false

            self.mutex.lock {
                isActive = (self.sessionLabels[session.id] != nil)
                canPoll = self.shouldPoll
            }

            // check session is still active
            guard canPoll && isActive else {
                return
            }

            // otherwise listen
            self.listen(to: session, completion: { (success, err) in
                if let e = err, !(e is NoMessageError) {
                    log("listen error: \(e)", .error)
                    let delay = DispatchTime.now() + 5.0
                    queue.asyncAfter(deadline: delay, execute: {
                        self.poll(session: session)
                    })
                } else {
                    queue.async(execute: {
                        self.poll(session: session);
                    })
                }
            })
        }
    }

    func listen(to session: Session, completion:((Bool, Error?)->Void)?) {
        let api = API()
        
        log("listening with: \(session.id)", .warning)
        
        api.receive(session.pairing.queue) { (result) in
        
            log("finished reading from queue")
            
            // check again that the session has not responded
            var isActive = false
            self.mutex.lock {
                isActive = (self.sessionLabels[session.id] != nil)
            }
            
            guard isActive else {
                completion?(false, SessionRemovedError())
                return
            }
            
            
            switch result {
            case .message(let msgs):
                for msg in msgs {
                    
                    do {
                        let req = try Request(from: session.pairing, sealed: msg.data)
                        try self.handle(request: req, session: session, communicationMedium: .sqs)
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
            sessionServiceUUIDS[cbuuid.uuidString] = session
            sessionActivity[cbuuid] = CommunicationActivity()
            bluetoothDelegate?.addServiceUUID(uuid: cbuuid)

            do {
                let wrappedKeyMessage = try NetworkMessage(
                    localData: session.pairing.keyPair.publicKey.wrap(to: session.pairing.workstationPublicKey),
                    header: .wrappedPublicKey)
                
                let api = API()
                api.send(to: session.pairing.queue, message: wrappedKeyMessage, handler: { (sendResult) in
                    switch sendResult {
                    case .sent:
                        log("success! sent response.")
                    case .failure(let e):
                        log("error sending response: \(e)", LogType.error)
                    default:
                        break
                    }
                })
                bluetoothDelegate?.writeToServiceUUID(uuid: cbuuid, message: wrappedKeyMessage)

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
        sessionServiceUUIDS.removeValue(forKey: cbuuid.uuidString)
        bluetoothDelegate?.removeServiceUUID(uuid: cbuuid)
        sessionActivity.removeValue(forKey: cbuuid)
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
    
    func hasCachedResponse(for session:Session,with request:Request) -> Bool {
        return requestCache?[CacheKey(session, request)] != nil
    }
    
    //MARK: Session Pairing Completion
    
    func waitForPairing(session:Session, timeout:TimeInterval = 10.0) -> Bool {
        let startTime = Date()        
        let cbuuid = session.pairing.uuid
        
        while true {
            mutex.lock()
            if let everActive = sessionActivity[cbuuid]?.everActive(), everActive {
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
    
    //MARK: Handle Logic
    func handle(request:Request, session:Session, communicationMedium: CommunicationMedium, completionHandler: (()->Void)? = nil) throws {
        mutex.lock()
        defer { mutex.unlock() }

        guard let _ = sessionLabels[session.id] else {
            throw SessionRemovedError()
        }

        if let _ = request.unpair {
            Analytics.postEvent(category: "device", action: "unpair", label: "request")
            SessionManager.shared.remove(session: session)
            removeLocked(session: session, sendUnpairResponse: false)
            throw SessionRemovedError()
        }

        let now = Date().timeIntervalSince1970
        if abs(now - Double(request.unixSeconds)) > Properties.requestTimeTolerance {
            throw InvalidRequestTimeError()
        }

        if let sessionActivity = sessionActivity[session.pairing.uuid] {
            sessionActivity.used(medium: communicationMedium)
            if sessionActivity.isInactive(medium: .bluetooth) {
                bluetoothDelegate?.refreshServiceUUID(uuid: session.pairing.uuid)
                sessionActivity.used(medium: .bluetooth)
            }
        }
        
        requestCache?.removeExpiredObjects()
        if  let cachedResponseData = requestCache?[CacheKey(session, request)] as? Data {
            let json:Object = try JSON.parse(data: cachedResponseData)
            let response = try Response(json: json)
            try self.send(session: session, response: response, completionHandler: completionHandler)
            return
        }
        
        // logic
        
        // if signature request AND we need a user approval, 
        // then exit and wait for it
        if request.sign != nil && Policy.needsUserApproval(for: session) {
            try handleRequestRequiresApproval(request: request, session: session, communicationMedium: communicationMedium, completionHandler: completionHandler)
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

    func handleRequestRequiresApproval(request: Request, session: Session, communicationMedium: CommunicationMedium, completionHandler: (() -> ())?) throws {
        pendingRequests?.removeExpiredObjects()
        if pendingRequests?.object(forKey: CacheKey(session, request)) != nil {
            throw RequestPendingError()
        }
        pendingRequests?.setObject("", forKey: CacheKey(session, request), expires: .seconds(Properties.requestTimeTolerance * 2))
        
        Policy.addPendingAuthorization(session: session, request: request)
        Policy.requestUserAuthorization(session: session, request: request)
        
        if request.sendACK {
            let arn = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? ""
            let ack = Response(requestID: request.id, endpoint: arn, approvedUntil: Policy.approvedUntilUnixSeconds(for: session), ack: AckResponse(), trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
            do {
                try send(session: session, response: ack)
            } catch (let e) {
                log("ack send error \(e)")
            }
        }
        
        Analytics.postEvent(category: "signature", action: "requires approval", label:communicationMedium.rawValue)
        completionHandler?()
    }
    
    
    func send(session:Session, response:Response, completionHandler: (()->Void)? = nil) throws {
        let sealedResponse = try response.seal(to: session.pairing)
        let message = NetworkMessage(localData: sealedResponse, header: .ciphertext)

        self.bluetoothDelegate?.writeToServiceUUID(uuid: session.pairing.uuid, message: message)
        
        let api = API()
        api.send(to: session.pairing.queue, message: message, handler: { (sendResult) in
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
        var me:MeResponse?
        
        if let signRequest = request.sign {
            let kp = try KeyManager.sharedInstance()
            
            var sig:String?
            var err:String?
            do {
                
                if signatureAllowed {
                    // only place where signature should occur
                    sig = try kp.keyPair.signAppendingSSHWirePubkeyToPayload(data: signRequest.data)
                    
                    LogManager.shared.save(theLog: SignatureLog(session: session.id, digest: signRequest.data.toBase64(), hostAuth: signRequest.hostAuth, signature: sig ?? "<err>", displayName: signRequest.display), deviceName: session.pairing.name)
                } else {
                    err = "rejected"
                    LogManager.shared.save(theLog: SignatureLog(session: session.id, digest: signRequest.data.toBase64(), hostAuth: signRequest.hostAuth, signature: "rejected", displayName: signRequest.display), deviceName: session.pairing.name)
                }

            } catch let e {
                err = "\(e)"
            }

            sign = SignResponse(sig: sig, err: err)
        }
        
        if let _ = request.me {
            let keyManager = try KeyManager.sharedInstance()
            me = MeResponse(me: MeResponse.Me(email: try keyManager.getMe(), publicKeyWire: try keyManager.keyPair.publicKey.wireFormat()))
        }
        
        let arn = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? ""
        
        let response = Response(requestID: request.id, endpoint: arn, approvedUntil: Policy.approvedUntilUnixSeconds(for: session), sign: sign, me: me, trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
        
        let responseData = try response.jsonData() as NSData
        
        requestCache?.setObject(responseData, forKey: CacheKey(session, request), expires: .seconds(300))
        
        return response

    }
}
