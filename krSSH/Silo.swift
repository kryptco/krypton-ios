//
//  Silo.swift
//  krSSH
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

typealias SessionLabel = String

struct SessionRemovedError:Error{}

private var sharedSilo:Silo?
class Silo {
    
    var sessionLabels:[SessionLabel:Session] = [:]
    var mutex = Mutex()
    
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
                        let req = try Request(key: to.pairing.key, sealed: msg)
                        let resp = try Silo.handle(request: req, id: to.id).seal(key: to.pairing.key)
                        
                        log("created response")
                        
                        
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
        }
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
            shouldPoll = false
        }
    }

    
    //MARK: Handle Logic
    class func handle(request:Request, id:String) throws -> Response {
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
                LogManager.shared.save(theLog: SignatureLog(session: id, digest: signRequest.digest, signature: sig ?? "<err>"))
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
        
        return Response(requestID: request.id, endpoint: arn, sign: sign, list: list, me: me)
    }
}
