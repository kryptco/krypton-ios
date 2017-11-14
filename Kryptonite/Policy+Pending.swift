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
    
    private static let pendingCacheName = "policy_pending_authorizations"
    static let pendingCache:Cache<NSData>? = try? Cache<NSData>(name: pendingCacheName, directory: Caches.directory(for: pendingCacheName))


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
        pendingCache?.removeExpiredObjects()
        
        guard   let pendingData = pendingCache?.allObjects().last,
            let pending =  try? PendingAuthorization(jsonData: pendingData as Data)
            else {
                return nil
        }
        
        return pending
    }
    
    static func addPendingAuthorization(session:Session, request:Request) {
        let pending = PendingAuthorization(session: session, request: request)
        
        do {
            let pendingData = try pending.jsonData()
            pendingCache?.setObject(pendingData as NSData, forKey: pending.cacheKey, expires: .seconds(Properties.requestTimeTolerance * 2))
        } catch {
            log ("json error: \(error)")
        }
    }
    
    static func removePendingAuthorization(session:Session, request:Request) {
        pendingCache?.removeObject(forKey: PendingAuthorization(session: session, request: request).cacheKey)
    }
    
    static func sendAllowedPendingIfNeeded() {
        pendingCache?.removeExpiredObjects()
        
        pendingCache?.allObjects().forEach {
            
            guard   let pending = try? PendingAuthorization(jsonData: $0 as Data)
            else {
                return
            }
            do {
                try Silo.shared.handle(request: pending.request, session: pending.session, communicationMedium: .internalPending)
                pendingCache?.removeObject(forKey: pending.cacheKey)
            } catch (let e) {
                log("got error \(e)", .error)
                return
            }
        }
    }
    
    static func rejectAllPendingIfNeeded() {
        pendingCache?.removeExpiredObjects()
        
        pendingCache?.allObjects().forEach {
            
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
