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

    }
    
    class var needsUserApproval:Bool {
        set(val) {
            UserDefaults.standard.set(val, forKey: StorageKey.userApproval.rawValue)
            UserDefaults.standard.removeObject(forKey: StorageKey.userLastApproved.rawValue)
            UserDefaults.standard.removeObject(forKey: StorageKey.userApprovalInterval.rawValue)
            UserDefaults.standard.synchronize()
        }
        get {
            let needsApproval =  UserDefaults.standard.bool(forKey: StorageKey.userApproval.rawValue)
            
            if  let lastApproved = UserDefaults.standard.object(forKey: StorageKey.userLastApproved.rawValue) as? Date
            {
                let approvalInterval = UserDefaults.standard.double(forKey: StorageKey.userApprovalInterval.rawValue)
                
                return -lastApproved.timeIntervalSinceNow > approvalInterval

            }
            return needsApproval
        }
    }
    
    class var approvedUntil:Date? {
        if  let lastApproved = UserDefaults.standard.object(forKey: StorageKey.userLastApproved.rawValue) as? Date
        {
            let approvalInterval = UserDefaults.standard.double(forKey: StorageKey.userApprovalInterval.rawValue)
            
            return lastApproved.addingTimeInterval(approvalInterval)
            
        }
        
        return nil
    }
    
    class var approvalTimeRemaining:String? {
        if  let lastApproved = UserDefaults.standard.object(forKey: StorageKey.userLastApproved.rawValue) as? Date
        {
            let approvalInterval = UserDefaults.standard.double(forKey: StorageKey.userApprovalInterval.rawValue)
            
            if -lastApproved.timeIntervalSinceNow > approvalInterval {
                return nil
            }
            
            return lastApproved.addingTimeInterval(approvalInterval + lastApproved.timeIntervalSinceNow).timeAgo(suffix: "")
        }
        
        return nil

    }
    
    static var currentViewController:UIViewController?
    
    static func allowFor(time:Interval) {
        UserDefaults.standard.set(Date(), forKey: StorageKey.userLastApproved.rawValue)
        UserDefaults.standard.set(time.rawValue, forKey: StorageKey.userApprovalInterval.rawValue)
        UserDefaults.standard.synchronize()
    }
    
    //MARK: Pending request
    
    static var pendingAuthorization:(Session, Request)?
    
    //MARK: Notification Actions

    static var authorizeCategory:UIUserNotificationCategory = {
        let cat = UIMutableUserNotificationCategory()
        cat.identifier = "authorize_identifier"
        cat.setActions([Policy.approveAction, Policy.approveTemporaryAction, Policy.rejectAction], for: UIUserNotificationActionContext.default)
        return cat
        
    }()
    
    static var approveAction:UIMutableUserNotificationAction = {
        var approve = UIMutableUserNotificationAction()
        
        approve.identifier = "approve_identifier"
        approve.title = "Allow once"
        approve.activationMode = UIUserNotificationActivationMode.background
        approve.isDestructive = false
        approve.isAuthenticationRequired = true
        
        return approve
    }()
    
    static var approveTemporaryAction:UIMutableUserNotificationAction = {
        var approve = UIMutableUserNotificationAction()
        
        approve.identifier = "approve_temp_identifier"
        approve.title = "Allow for 1 hour"
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
        reject.isAuthenticationRequired = false
        
        return reject
    }()
    
    //MARK: Notification Push

    class func requestUserAuthorization(session:Session, request:Request) {
        
        guard UIApplication.shared.applicationState != .active else {
            Policy.pendingAuthorization = nil
            Policy.currentViewController?.requestUserAuthorization(session: session, request: request)
            return
        }
        
        // set the pending
        Policy.pendingAuthorization = (session, request)
        
        // present notification
        let notification = UILocalNotification()
        notification.alertBody = "Request from \(session.pairing.displayName): \(request.sign?.command ?? "SSH login")"
        notification.soundName = UILocalNotificationDefaultSoundName
        notification.category = Policy.authorizeCategory.identifier
        notification.userInfo = ["session_id": session.id, "request": request.jsonMap]

        UIApplication.shared.presentLocalNotificationNow(notification)
    }
    
    class func notifyUser(session:Session, request:Request) {
        let notification = UILocalNotification()

        notification.alertBody = "\(session.pairing.displayName): \(request.sign?.command ?? "SSH login")"
        notification.soundName = UILocalNotificationDefaultSoundName

        UIApplication.shared.presentLocalNotificationNow(notification)
    }
}

extension UIViewController {
    
    
    func requestUserAuthorization(session:Session, request:Request) {
        
        
        let alertController:UIAlertController = UIAlertController(title: "\(session.pairing.displayName): \(request.sign?.command ?? "SSH login")", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        
        alertController.addAction(UIAlertAction(title: Policy.approveAction.title, style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in

            do {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: true)
                try Silo.shared.send(session: session, response: resp, completionHandler: nil)
                
            } catch (let e) {
                log("send error \(e)", .error)
                return
            }
            
        }))
        
        alertController.addAction(UIAlertAction(title: Policy.approveTemporaryAction.title, style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            Policy.allowFor(time: Policy.Interval.oneHour)
            
            do {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: true)
                try Silo.shared.send(session: session, response: resp, completionHandler: nil)
                
            } catch (let e) {
                log("send error \(e)", .error)
                return
            }

            
        }))

        
        
        alertController.addAction(UIAlertAction(title: Policy.rejectAction.title, style: UIAlertActionStyle.cancel, handler: { (action:UIAlertAction) -> Void in
            
            do {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: false)
                try Silo.shared.send(session: session, response: resp, completionHandler: nil)
                
            } catch (let e) {
                log("send error \(e)", .error)
                return
            }

            
        }))
        
        self.present(alertController, animated: true, completion: nil)


    }
}

