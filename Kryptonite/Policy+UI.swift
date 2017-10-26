//
//  Policy+UI.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UserNotifications

extension Policy {
    
    //MARK: Notification Actions
    static var authorizeCategory:UNNotificationCategory = {
        if #available(iOS 11.0, *) {
            return UNNotificationCategory(identifier: authorizeCategoryIdentifier,
                                   actions: [Policy.approveAction, Policy.approveTemporaryAction, Policy.rejectAction],
                                   intentIdentifiers: [],
                                   hiddenPreviewsBodyPlaceholder: "Kryptonite Request",
                                   options: .customDismissAction)
        } else {
            return UNNotificationCategory(identifier: authorizeCategoryIdentifier,
                                   actions: [Policy.approveAction, Policy.approveTemporaryAction, Policy.rejectAction],
                                   intentIdentifiers: [],
                                   options: .customDismissAction)
        }
    }()
    
    
    static var approveAction:UNNotificationAction = {
        return UNNotificationAction(identifier: ActionIdentifier.approve.rawValue,
                                    title: "Allow once",
                                    options: .authenticationRequired)
    }()
    
    
    static var approveTemporaryAction:UNNotificationAction = {
        return UNNotificationAction(identifier: ActionIdentifier.temporary.rawValue,
                                    title: "Allow for 3 hours",
                                    options: .authenticationRequired)
    }()
    
    static var rejectAction:UNNotificationAction = {
        return UNNotificationAction(identifier: ActionIdentifier.reject.rawValue,
                                    title: "Reject",
                                    options: .destructive)
    }()

    
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
        dispatchMain {
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
        
    }
    
    
    class func notifyUser(errorMessage:String, session:Session) {
        dispatchMain {
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
}
