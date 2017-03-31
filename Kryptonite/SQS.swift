//
//  SQS.swift
//  Kryptonite
//
//  Created by Alex Grinman on 3/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

typealias SessionID = String

class SQSManager:TransportMedium {
    
    var handler:TransportControlRequestHandler
    var sessionLabels:[SessionID:Session] = [:]
    var mutex = Mutex()
    
    var medium:CommunicationMedium {
        return .sqs
    }

    required init(handler:@escaping TransportControlRequestHandler) {
        self.handler = handler
    }
    
    //MARK: Transport
    func send(message:NetworkMessage, for session:Session, completionHandler: (()->Void)?) {
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
    
    func add(session: Session) {
        mutex.lock {
            guard sessionLabels[session.id] == nil else {
                return
            }
            sessionLabels[session.id] = session
        }
        
        self.poll(session: session)
    }
    
    func remove(session: Session) {
        defer { mutex.unlock() }
        mutex.lock()
        
        sessionLabels.removeValue(forKey: session.id)
    }
    
    private var backgroundBoolMutex = Mutex()
    private var inBackground:Bool = false

    func willEnterBackground() {
        backgroundBoolMutex.lock {
            inBackground = true
        }
    }
    
    func willEnterForeground() {
        backgroundBoolMutex.lock {
            inBackground = false
        }

        var sessions:[Session] = []
        mutex.lock {
            sessions = [Session](self.sessionLabels.values)
        }
        
        sessions.forEach({ self.poll(session: $0)})
    }
    
    func refresh(for session:Session) {
        // do nothing, future: refresh connection?
    }
    
    
    //MARK: SQS Polling
    func poll(session:Session) {
        
        // suspend the polling in the background
        var isBackground = false
        backgroundBoolMutex.lock {
          isBackground = self.inBackground
        }
        if isBackground {
            return
        }
        
        let queue = DispatchQueue(label: "read-queue-\(session.id)")
        queue.async {
            
            log("polling sqs for \(session.pairing.displayName)")
            var isActive = false
            
            self.mutex.lock {
                isActive = (self.sessionLabels[session.id] != nil)
            }
            
            // check session is still active
            guard isActive else {
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
                        try self.handler(self.medium, req, session, nil)
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
    
    func stop() {
        mutex.lock {
            sessionLabels = [:]
        }
    }
}
