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
    static var authorizeCategory:UIUserNotificationCategory {
        let cat = UIMutableUserNotificationCategory()
        cat.identifier = authorizeCategoryIdentifier
        cat.setActions([Policy.approveAction, Policy.approveTemporaryAction, Policy.rejectAction], for: UIUserNotificationActionContext.default)
        return cat
    }
    
    
    static var approveAction:UIMutableUserNotificationAction = {
        var approve = UIMutableUserNotificationAction()
        
        approve.identifier = ActionIdentifier.approve.rawValue
        approve.title = "Allow once"
        approve.activationMode = UIUserNotificationActivationMode.background
        approve.isDestructive = false
        approve.isAuthenticationRequired = true
        
        return approve
    }()
    
    
    static var approveTemporaryAction:UIMutableUserNotificationAction {
        let approve = UIMutableUserNotificationAction()
        
        approve.identifier = ActionIdentifier.temporary.rawValue
        approve.title = "Allow for " + Policy.temporaryApprovalInterval.description
        approve.activationMode = UIUserNotificationActivationMode.background
        approve.isDestructive = false
        approve.isAuthenticationRequired = true
        
        return approve
    }
    
    static var rejectAction:UIMutableUserNotificationAction = {
        var reject = UIMutableUserNotificationAction()
        
        reject.identifier = ActionIdentifier.reject.rawValue
        reject.title = "Reject"
        reject.activationMode = UIUserNotificationActivationMode.background
        reject.isDestructive = true
        reject.isAuthenticationRequired = false
        
        return reject
    }()
    
    class func teamDidUpdate() {
        // update push notifications
        (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
    }
    
    class func requestUserAuthorization(session:Session, request:Request) {
        dispatchMain {
            switch UIApplication.shared.applicationState {
                
            case .background: // Background: then present local notification
                Notify.shared.present(request: request, for: session)
                
            case .inactive: // Inactive: wait and try again
                dispatchAfter(delay: 1.0, task: {
                    Policy.requestUserAuthorization(session: session, request: request)
                })
                
            case .active:
                // if we are already presenting, don't try to present until finished
                guard Current.viewController?.presentedViewController is ApproveController == false
                    else {
                        return
                }
                
                // current view controller hasn't loaded, but application active
                if Current.viewController == nil {
                    dispatchAfter(delay: 1.0, task: {
                        Policy.requestUserAuthorization(session: session, request: request)
                    })
                    return
                }
                
                // request foreground approval
                Current.viewController?.requestUserAuthorization(session: session, request: request)
                
            }
        }
    }
    
    class func notifyUser(session:Session, request:Request) {
        
        
        switch UIApplication.shared.applicationState {
            
        case .background: // Background: then present local notification
            guard Policy.shouldShowApprovedNotifications(for: session) else {
                log("skip sending push notification on approved request due to policy setting")
                return
            }
          
            Notify.shared.presentApproved(request: request, for: session)
            
        case .inactive: // Inactive: wait and try again
            dispatchAfter(delay: 1.0, task: {
                Policy.notifyUser(session: session, request: request)
            })
            
        case .active:
            guard Current.viewController?.presentedViewController is AutoApproveController == false
            else {
                return
            }
            
            Current.viewController?.showApprovedRequest(session: session, request: request)
        }
        
        
    }
    
    
    class func notifyUser(errorMessage:String, session:Session) {
        
        switch UIApplication.shared.applicationState {
            
        case .background: // Background: then present local notification
            Notify.shared.presentError(message: errorMessage, session: session)
            
        case .inactive: // Inactive: wait and try again
            dispatchAfter(delay: 1.0, task: {
                Policy.notifyUser(errorMessage: errorMessage, session: session)
            })
            
        case .active:
            guard Current.viewController?.presentedViewController is AutoApproveController == false
                else {
                    return
            }
            
            Current.viewController?.showFailedResponse(errorMessage: errorMessage, session: session)
        }
    }
    
}
