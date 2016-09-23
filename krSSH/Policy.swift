//
//  Policy.swift
//  krSSH
//
//  Created by Alex Grinman on 9/14/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


class Policy {

    //MARK: Settings
    enum StorageKey:String {
        case userApproval = "policy_user_approval"
    }
    
    class var needsUserApproval:Bool {
        set(val) {
            UserDefaults.standard.set(val, forKey: StorageKey.userApproval.rawValue)
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.bool(forKey: StorageKey.userApproval.rawValue) 
        }
    }
    
    
    //MARK: Notification Actions

    static var authorizeCategory:UIUserNotificationCategory = {
        let cat = UIMutableUserNotificationCategory()
        cat.identifier = "authorize_identifier"
        cat.setActions([Policy.approveAction, Policy.rejectAction], for: UIUserNotificationActionContext.default)
        return cat
        
    }()
    
    static var approveAction:UIMutableUserNotificationAction = {
        var approve = UIMutableUserNotificationAction()
        
        approve.identifier = "approve_identifier"
        approve.title = "Allow"
        approve.activationMode = UIUserNotificationActivationMode.background
        approve.isDestructive = false
        approve.isAuthenticationRequired = true
        
        return approve
    }()
    
    static var rejectAction:UIMutableUserNotificationAction = {
        var reject = UIMutableUserNotificationAction()
        
        reject.identifier = "reject_identifier"
        reject.title = "Reject"
        reject.activationMode = UIUserNotificationActivationMode.background
        reject.isDestructive = true
        reject.isAuthenticationRequired = true
        
        return reject
    }()
    
    //MARK: Notification Push

    class func requestUserAuthorization(session:Session, request:Request) {
        let notification = UILocalNotification()
        notification.fireDate = Date()
        notification.alertBody = "\(session.pairing.name) is requesting to use your key for '\(request.sign?.command ?? "SSH login")'."
        notification.soundName = UILocalNotificationDefaultSoundName
        
        notification.category = Policy.authorizeCategory.identifier
        notification.userInfo = ["session_id": session.id, "request": request.jsonMap]

        dispatchMain {
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    class func notifyUser(session:Session, request:Request) {
        let notification = UILocalNotification()
        notification.fireDate = Date()
        
        notification.alertBody = "\(session.pairing.name) just used your key for '\(request.sign?.command ?? "SSH login")'."
        notification.soundName = UILocalNotificationDefaultSoundName
        
        dispatchMain {
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
}



