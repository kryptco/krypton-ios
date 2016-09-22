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
        approve.title = "Approve"
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

    class func notifyUser(session:Session, request:Request) {
        let notification = UILocalNotification()
        notification.fireDate = Date()
        notification.alertBody = "\(session.pairing.name) just used your key to login with SSH"
        notification.soundName = UILocalNotificationDefaultSoundName
        
        if Policy.needsUserApproval {
            notification.category = Policy.authorizeCategory.identifier
            notification.userInfo = ["session_id": session.id, "request": request.jsonMap]
        }
        
        UIApplication.shared.scheduleLocalNotification(notification)
    }
}

extension AppDelegate {
    
    @objc(application:handleActionWithIdentifier:forLocalNotification:completionHandler:) func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
        
        guard identifier == Policy.approveAction.identifier else {
            log("user rejected", .warning)
            return
        }
        
        guard   let sessionID = notification.userInfo?["session_id"] as? String,
                let session = SessionManager.shared.get(id: sessionID),
                let requestJSON = notification.userInfo?["request"] as? JSON,
                let request = try? Request(json: requestJSON)
        else {
                
            log("invalid notification", .error)
            return
        }
        
        do {
            let resp = try Silo.handle(request: request, session: session).seal(key: session.pairing.symmetricKey)
            
            Silo.shared.bluetoothDelegate.writeToServiceUUID(uuid: session.pairing.uuid, data: resp)

            API().send(to: session.pairing.queue, message: resp.toBase64(), handler: { (sendResult) in
                switch sendResult {
                case .sent:
                    log("success! sent response.")
                case .failure(let e):
                    log("error sending response: \(e)", LogType.error)
                default:
                    break
                }
                
                completionHandler()
                
            })
        } catch (let e) {
            log("handle error \(e)", .error)
            completionHandler()
            return
        }
        
    }
}



