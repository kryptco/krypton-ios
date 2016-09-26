//
//  Silo.swift
//  krSSH
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import CoreBluetooth

typealias SessionLabel = String

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
        
        try handle(request: req, session: session)
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
                    if let e = err {
                        log("listen error: \(e)", .error)
                    }
                    
                    pauseMutex.unlock()
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
                        try self.handle(request: req, session: to)
                    } catch (let e) {
                        log("error responding: \(e)", LogType.error)
                    }
                }
                break
            case .sent:
                log("sent")
                completion?(true, nil)

            case .failure(let e):
                log("error recieving: \(e)", LogType.error)
                completion?(false, e)
            }
            
            completion?(true, nil)
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

    func remove(session:Session) {
        mutex.lock {
            sessionLabels.removeValue(forKey: session.id)
            let cbuuid = session.pairing.uuid
            sessionServiceUUIDS.removeValue(forKey: cbuuid)
            bluetoothDelegate.removeServiceUUID(uuid: cbuuid)
        }
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
    
    func handle(request:Request, session:Session, completionHandler: (()->Void)? = nil) throws {
        mutex.lock()
        defer { mutex.unlock() }

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
            completionHandler?()
            return
        }
        
        
        // otherwise, continue with creating and sending the response
        let response = try responseFor(request: request, session: session)
        
        if response.sign != nil {
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
    func lockResponseFor(request:Request, session:Session) throws -> Response {
        mutex.lock()
        defer { mutex.unlock() }
        return try responseFor(request: request, session: session)
    }
    
    // precondition: mutex locked
    func responseFor(request:Request, session:Session) throws -> Response {
        var sign:SignResponse?
        var list:ListResponse?
        var me:MeResponse?
        
        if let signRequest = request.sign {
            let kp = try KeyManager.sharedInstance()
            
            var sig:String?
            var err:String?
            do {
                
                // only place where signature should occur
                
                let digestData = try signRequest.digest.fromBase64()
                sig = try kp.keyPair.sign(digest: digestData)
                
                log("signed: \(sig)")
                
                LogManager.shared.save(theLog: SignatureLog(session: session.id, digest: signRequest.digest, signature: sig ?? "<err>", command: signRequest.command))
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_log"), object: nil)
                
            } catch let e {
                guard e is CryptoError else {
                    throw e
                }

                err = "\(e)"
                throw e
            }
            
            
            sign = SignResponse(sig: sig, err: err)
        }
        
        if let _ = request.list {
            list = ListResponse(peers: PeerManager.shared.all)
        }
        if let _ = request.me {
            me = MeResponse(me: try KeyManager.sharedInstance().getMe())
        }
        
        let arn = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? ""
        
        let response = Response(requestID: request.id, endpoint: arn, sign: sign, list: list, me: me)
        
        let responseData = try response.jsonData() as NSData
        
        requestCache?.setObject(responseData, forKey: request.id, expires: .seconds(300))
        
        return response

    }
}
