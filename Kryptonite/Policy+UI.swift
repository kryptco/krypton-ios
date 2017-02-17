//
//  Policy+UI.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension Policy {
    
    //MARK: Notification Actions
    static var authorizeCategory:UIUserNotificationCategory = {
        let cat = UIMutableUserNotificationCategory()
        cat.identifier = authorizeCategoryIdentifier
        cat.setActions([Policy.approveAction, Policy.approveTemporaryAction, Policy.rejectAction], for: UIUserNotificationActionContext.default)
        return cat
        
    }()
    
    
    static var approveAction:UIMutableUserNotificationAction = {
        var approve = UIMutableUserNotificationAction()
        
        approve.identifier = ActionIdentifier.approve.rawValue
        approve.title = "Allow once"
        approve.activationMode = UIUserNotificationActivationMode.background
        approve.isDestructive = false
        approve.isAuthenticationRequired = true
        
        return approve
    }()
    
    
    static var approveTemporaryAction:UIMutableUserNotificationAction = {
        var approve = UIMutableUserNotificationAction()
        
        approve.identifier = ActionIdentifier.temporary.rawValue
        approve.title = "Allow for 1 hour"
        approve.activationMode = UIUserNotificationActivationMode.background
        approve.isDestructive = false
        approve.isAuthenticationRequired = true
        
        return approve
    }()
    
    static var rejectAction:UIMutableUserNotificationAction = {
        var reject = UIMutableUserNotificationAction()
        
        reject.identifier = ActionIdentifier.reject.rawValue
        reject.title = "Reject"
        reject.activationMode = UIUserNotificationActivationMode.background
        reject.isDestructive = true
        reject.isAuthenticationRequired = false
        
        return reject
    }()

    
    class func requestUserAuthorization(session:Session, request:Request) {
        // if we are already presenting, don't try to present until finished
        guard Current.viewController?.presentedViewController is ApproveController == false
            else {
                return
        }
        
        guard UIApplication.shared.applicationState != .inactive else {
            dispatchAfter(delay: 1.0, task: {
                Policy.requestUserAuthorization(session: session, request: request)
            })
            return
        }
        
        guard UIApplication.shared.applicationState != .active else {
            Current.viewController?.requestUserAuthorization(session: session, request: request)
            return
        }
        
        
        // present notification
        Notify.shared.present(request: request, for: session)
    }
    
    class func notifyUser(session:Session, request:Request) {
        guard Current.viewController?.presentedViewController is AutoApproveController == false
            else {
                return
        }
        
        guard UIApplication.shared.applicationState != .active else {
            Current.viewController?.showApprovedRequest(session: session, request: request)
            return
        }
        
        // present notification
        Notify.shared.presentApproved(request: request, for: session)
    }
}
