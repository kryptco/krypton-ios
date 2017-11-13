//
//  Policy+Pending.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/12/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import AwesomeCache

extension Policy {
    /// Pending Authoirizations
    struct PendingAuthorization:Jsonable, Equatable {
        let session:Session
        let request:Request
        
        init (session:Session, request:Request) {
            self.session = session
            self.request = request
        }
        
        init(json:Object) throws {
            session = try Session(json: json ~> "session")
            request = try Request(json: json ~> "request")
        }
        
        var object:Object {
            return ["session": session.object, "request": request.object]
        }
        
        var cacheKey:String {
            return CacheKey(session, request)
        }
        
    }
    
    static var lastPendingAuthorization:PendingAuthorization? {
        let cache = try? Cache<NSData>(name: "policy_pending_authorizations", directory: policyCacheURL)
        cache?.removeExpiredObjects()
        
        guard   let pendingData = cache?.allObjects().last,
            let pending =  try? PendingAuthorization(jsonData: pendingData as Data)
            else {
                return nil
        }
        
        return pending
    }
    
    static func addPendingAuthorization(session:Session, request:Request) {
        let cache = try? Cache<NSData>(name: "policy_pending_authorizations", directory: policyCacheURL)
        let pending = PendingAuthorization(session: session, request: request)
        
        do {
            let pendingData = try pending.jsonData()
            cache?.setObject(pendingData as NSData, forKey: pending.cacheKey, expires: .seconds(Properties.requestTimeTolerance * 2))
        } catch {
            log ("json error: \(error)")
        }
    }
    
    static func removePendingAuthorization(session:Session, request:Request) {
        let cache = try? Cache<NSData>(name: "policy_pending_authorizations", directory: policyCacheURL)
        cache?.removeObject(forKey: PendingAuthorization(session: session, request: request).cacheKey)
    }
    
    static func sendAllowedPendingIfNeeded() {
        let cache = try? Cache<NSData>(name: "policy_pending_authorizations", directory: policyCacheURL)
        cache?.removeExpiredObjects()
        
        cache?.allObjects().forEach {
            
            guard   let pending = try? PendingAuthorization(jsonData: $0 as Data),
                    false == Policy.SessionSettings(for: pending.session).isAllowed(for: pending.request)
                else {
                    return
            }
            
            let session = pending.session
            let request = pending.request
            
            Policy.removePendingAuthorization(session: session, request: request)
            do {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, allowed: true)
                try TransportControl.shared.send(resp, for: session)
                
                if let errorMessage = resp.body.error {
                    Policy.notifyUser(errorMessage: errorMessage, session: session)
                } else {
                    Policy.notifyUser(session: session, request: request)
                }
            } catch (let e) {
                log("got error \(e)", .error)
                return
            }
        }
    }
    
    static func rejectAllPendingIfNeeded() {
        let cache = try? Cache<NSData>(name: "policy_pending_authorizations", directory: policyCacheURL)
        cache?.removeExpiredObjects()
        
        cache?.allObjects().forEach {
            
            guard let pending = try? PendingAuthorization(jsonData: $0 as Data)
                else {
                    return
            }
            
            let session = pending.session
            let request = pending.request
            
            Policy.removePendingAuthorization(session: session, request: request)
            
            do {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, allowed: false)
                try TransportControl.shared.send(resp, for: session)
            } catch (let e) {
                log("got error \(e)", .error)
                return
            }
        }
    }
}
