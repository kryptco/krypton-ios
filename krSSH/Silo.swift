//
//  Silo.swift
//  krSSH
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

typealias SessionLabel = String

private var sharedSilo:Silo?
class Silo {
    
    var sessionLabels:[SessionLabel:Bool] = [:]
    var mutex = Mutex()
    
    class var shared:Silo {
        guard let ss = sharedSilo else {
            sharedSilo = Silo()
            return sharedSilo!
        }
        return ss
    }
    
    
    private func listen(to: Session, queue:DispatchQueue) {
        
        // check session is still activee
        var isActive = false
        self.mutex.lock {
            isActive = (self.sessionLabels[to.id] != nil)
        }
        
        guard isActive else {
            return
        }
        
        queue.async {
            let api = API()
            
            log("listening with: \(to.id)", .warning)
            
            api.receive(to.pairing.queue) { (result) in
                switch result {
                case .message(let msgs):
                    for msg in msgs {
                        
                        do {
                            let req = try Request(key: to.pairing.key, sealed: msg)
                            let resp = try Silo.handle(request: req).seal(key: to.pairing.key)
                            
                            api.send(to: to.pairing.queue, message: resp, handler: { (sendResult) in
                                switch sendResult {
                                case .sent:
                                    log("success! sent response.")
                                case .failure(let e):
                                    log("error sending response: \(e)", LogType.error)
                                default:
                                    break
                                }
                            })
                        } catch (let e) {
                            log("error responding: \(e)", LogType.error)
                        }
                    }
                    break
                case .sent:
                    log("sent")
                case .failure(let e):
                    log("error recieving: \(e)", LogType.error)
                }
                
                self.listen(to: to, queue: queue)
            }

        }
    }
    
    
    
    //MARK: Control
    func add(session:Session) {
        mutex.lock {
            guard sessionLabels[session.id] == nil else {
                return
            }
            
            sessionLabels[session.id] = true
        }
        
        let queue = DispatchQueue(label: session.id)

        listen(to: session, queue: queue)
    }
    
    func remove(session:Session) {
        mutex.lock {
            sessionLabels.removeValue(forKey: session.id)
        }
    }
    
    func add(sessions:[Session]) {
        sessions.forEach({ self.add(session: $0) })
    }
    
    func stop() {
        mutex.lock {
            sessionLabels = [:]
        }
    }

    
    //MARK: Handle Logic
    class func handle(request:Request) throws -> Response {
        var sign:SignResponse?
        var list:ListResponse?
        var me:MeResponse?

        if let signRequest = request.sign {
            let kp = try KeyManager.sharedInstance()
            
            var sig:String?
            var err:String?
            do {
                sig = try kp.keyPair.sign(digest: signRequest.digest)
                log("signed: \(sig)")
                SessionManager.logMutex.lock {
                    SessionManager.logs.append(SignatureLog(sig: sig!))
                }
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
        
        return Response(requestID: request.id, endpoint: "", sign: sign, list: list, me: me)
    }
}
