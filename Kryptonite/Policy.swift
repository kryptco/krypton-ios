//
//  Policy.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/14/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation



class Policy {
    
    enum Interval:TimeInterval {
        //case fifteenSeconds = 15
        case oneHour = 3600 
    }

    
    //MARK: Settings
    enum StorageKey:String {
        case userApproval = "policy_user_approval"
        case userLastApproved = "policy_user_last_approved"
        case userApprovalInterval = "policy_user_approval_interval"
        
        func key(id:String) -> String {
            return "\(self.rawValue)_\(id)"
        }

    }
    
    static var pendingAuthorizationMutex = Mutex()
    static var pendingAuthorizations:[PendingAuthorization] = []
    
    // Category Identifiers
    static let authorizeCategoryIdentifier = "authorize_identifier"
    
    enum ActionIdentifier:String {
        case approve = "approve_identifier"
        case temporary = "approve_temp_identifier"
        case reject = "reject_identifier"
    }
    
    
    class func set(needsUserApproval:Bool, for session:Session) {
        UserDefaults.group?.set(needsUserApproval, forKey: StorageKey.userApproval.key(id: session.id))
        UserDefaults.group?.removeObject(forKey: StorageKey.userLastApproved.key(id: session.id))
        UserDefaults.group?.removeObject(forKey: StorageKey.userApprovalInterval.key(id: session.id))
        UserDefaults.group?.synchronize()
    }
    
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
    

    
    static func allow(session:Session, for time:Interval) {
        UserDefaults.group?.set(Date(), forKey: StorageKey.userLastApproved.key(id: session.id))
        UserDefaults.group?.set(time.rawValue, forKey: StorageKey.userApprovalInterval.key(id: session.id))
        UserDefaults.group?.synchronize()
        
        Policy.sendAllowedPendingIfNeeded()
    }
    
    //MARK: Pending request
    
    struct PendingAuthorization:Equatable {
        let session:Session
        let request:Request
    }
    
    static func addPendingAuthorization(session:Session, request:Request) {
        Policy.pendingAuthorizationMutex.lock {
            Policy.pendingAuthorizations.append(PendingAuthorization(session: session, request: request))
        }
    }
    
    static func removePendingAuthorization(session:Session, request:Request) {
        Policy.pendingAuthorizationMutex.lock {
            let pending = PendingAuthorization(session: session, request: request)
            if let pendingIndex = Policy.pendingAuthorizations.index(where: { $0 == pending }) {
                Policy.pendingAuthorizations.remove(at: pendingIndex)
            }
        }
    }
    
    static func sendAllowedPendingIfNeeded() {
        
        var pending:[PendingAuthorization]?
        Policy.pendingAuthorizationMutex.lock {
            pending = Policy.pendingAuthorizations.filter({ Policy.needsUserApproval(for: $0.session) == false })
        }
        
        pending?.forEach {
            Policy.removePendingAuthorization(session: $0.session, request: $0.request)
            do {
                let resp = try Silo.shared.lockResponseFor(request: $0.request, session: $0.session, signatureAllowed: true)
                try Silo.shared.send(session: $0.session, response: resp, completionHandler: nil)
                
                Policy.notifyUser(session: $0.session, request: $0.request)
                
            } catch (let e) {
                log("handle error \(e)", .error)
                return
            }
        }
    }
    


    
}



func ==(l:Policy.PendingAuthorization, r:Policy.PendingAuthorization) -> Bool {
    return  l.session.id == r.session.id &&
            l.request.id == r.request.id
}


