//
//  Policy.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/14/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON
import AwesomeCache

class Policy {
    
    enum Interval:TimeInterval {
        //case fifteenSeconds = 15
        case oneHour = 3600
        case threeHours = 10800
    }

    
    //MARK: Settings
    enum StorageKey:String {
        case userApproval = "policy_user_approval"
        case userLastApproved = "policy_user_last_approved"
        case userApprovalInterval = "policy_user_approval_interval"
        
        case showApprovedNotifications = "policy_show_approved_notifications"
        
        func key(id:String) -> String {
            return "\(self.rawValue)_\(id)"
        }

    }
    
    // Category Identifiers
    static let authorizeCategoryIdentifier = "authorize_identifier"
    
    enum ActionIdentifier:String {
        case approve = "approve_identifier"
        case temporary = "approve_temp_identifier"
        case reject = "reject_identifier"
    }
    
    // MARK: Setters for Policy Settings
    class func set(needsUserApproval:Bool, for session:Session) {
        UserDefaults.group?.set(needsUserApproval, forKey: StorageKey.userApproval.key(id: session.id))
        UserDefaults.group?.removeObject(forKey: StorageKey.userLastApproved.key(id: session.id))
        UserDefaults.group?.removeObject(forKey: StorageKey.userApprovalInterval.key(id: session.id))
        UserDefaults.group?.synchronize()
    }
    
    class func allow(session:Session, for time:Interval) {
        UserDefaults.group?.set(Date(), forKey: StorageKey.userLastApproved.key(id: session.id))
        UserDefaults.group?.set(time.rawValue, forKey: StorageKey.userApprovalInterval.key(id: session.id))
        UserDefaults.group?.synchronize()
        
        Policy.sendAllowedPendingIfNeeded()
    }

    class func set(shouldShowApprovedNotifications:Bool, for session:Session) {
        UserDefaults.group?.set(shouldShowApprovedNotifications, forKey: StorageKey.showApprovedNotifications.key(id: session.id))
        UserDefaults.group?.synchronize()
    }
    
    // MARK: Getters for Policy Settings
    class func needsUserApproval(for session:Session) -> Bool {
        if  let lastApproved = UserDefaults.group?.object(forKey: StorageKey.userLastApproved.key(id: session.id)) as? Date
        {
            let approvalInterval = UserDefaults.group?.double(forKey: StorageKey.userApprovalInterval.key(id: session.id)) ?? 0
            
            return -lastApproved.timeIntervalSinceNow > approvalInterval
            
        }

        guard UserDefaults.group?.value(forKey: StorageKey.userApproval.key(id: session.id)) != nil else {
            return true
        }
        
        guard let needsApproval = UserDefaults.group?.bool(forKey: StorageKey.userApproval.key(id: session.id))
        else {
            return true
        }
        
        return needsApproval
    }

    class func approvedUntil(for session:Session) -> Date? {
        guard
            let lastApproved = UserDefaults.group?.object(forKey: StorageKey.userLastApproved.key(id: session.id)) as? Date ,
            let approvalInterval = UserDefaults.group?.double(forKey: StorageKey.userApprovalInterval.key(id: session.id))
        else {
            return nil
        }
        
        return lastApproved.addingTimeInterval(approvalInterval)
    }

    class func approvedUntilUnixSeconds(for session:Session) -> Int? {
        if let time = Policy.approvedUntil(for: session)?.timeIntervalSince1970 {
            return Int(time)
        }
        return nil
    }

    class func approvalTimeRemaining(for session:Session) -> String? {
        if  let lastApproved = UserDefaults.group?.object(forKey: StorageKey.userLastApproved.key(id: session.id)) as? Date,
            let approvalInterval = UserDefaults.group?.double(forKey: StorageKey.userApprovalInterval.key(id: session.id))
        {
            
            if -lastApproved.timeIntervalSinceNow > approvalInterval {
                return nil
            }
            
            return lastApproved.addingTimeInterval(approvalInterval + lastApproved.timeIntervalSinceNow).timeAgo(suffix: "")
        }
        
        return nil
    }
    
    class func shouldShowApprovedNotifications(for session:Session) -> Bool {
        
        guard let shouldShow = UserDefaults.group?.object(forKey: StorageKey.showApprovedNotifications.key(id: session.id)) as? Bool
        else {
            return true
        }
        
        return shouldShow
    }
    
    
    //MARK: Pending Authoirizations
    
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
    
    private static var policyCacheURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID)?.appendingPathComponent("policy_cache")
    
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
                    Policy.needsUserApproval(for: pending.session) == false
            else {
                return
            }
            
            let session = pending.session
            let request = pending.request
            
            Policy.removePendingAuthorization(session: session, request: request)
            do {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: true)
                try TransportControl.shared.send(resp, for: session)
                
                Policy.notifyUser(session: session, request: request)
                
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
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: false)
                try TransportControl.shared.send(resp, for: session)
            } catch (let e) {
                log("got error \(e)", .error)
                return
            }
        }
    }

    
}



func ==(l:Policy.PendingAuthorization, r:Policy.PendingAuthorization) -> Bool {
    return  l.session.id == r.session.id &&
            l.request.id == r.request.id
}


