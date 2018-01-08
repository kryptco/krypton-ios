//
//  AppDelegate+Notifications.swift
//  Krypton
//
//  Created by Alex Grinman on 10/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UserNotifications
import JSON

enum LocalNotificationProcessError:Error {
    case invalidUserInfoPayload
    case unknownSession
    case mismatchingAlertBody
    case invalidSilentNotificationPayload
}

extension AppDelegate {
    
    /// UserNotificationCenterDelegate
    
    // foreground notification
    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Swift.Void) {
        
        log("willPresentNotifcation - Foreground", .warning)
        completionHandler(.sound)
    }
    
    
    // MARK: SILENT NOTIFICATION PROCESSING
    // silent notification
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        log("didReceieveRemoteNotification")
                
        // silent notification (untrusted)
        do {
            guard let notificationDict = userInfo["aps"] as? [String:Any],
                let ciphertextB64 = notificationDict["c"] as? String,
                let ciphertext = try? ciphertextB64.fromBase64(),
                let queue = notificationDict["queue"] as? String
                else {
                    throw LocalNotificationProcessError.invalidSilentNotificationPayload
            }
            
            guard let session = SessionManager.shared.get(queue: queue) else {
                throw LocalNotificationProcessError.unknownSession
            }

            let sealed = try NetworkMessage(networkData: ciphertext).data
            let request = try Request(from: session.pairing, sealed: sealed)
            
            try TransportControl.shared.handle(medium: .silentNotification, with: request, for: session, completionHandler: {
                completionHandler(.newData)
            })
            
        } catch {
            log("invalid silent kryptonite request payload: \(error)", .error)
            completionHandler(.noData)
        }
        
    }

    
    // MARK: REMOTE NOTIFICATION ACTION OR OPENED
    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {

        do {
            guard let payload = response.notification.request.content.userInfo as? JSON.Object else {
                throw LocalNotificationProcessError.invalidUserInfoPayload
            }
            
            let verifiedLocalNotification = try LocalNotificationAuthority.verifiedLocalNotification(with: payload)
            
            guard let session = SessionManager.shared.get(id: verifiedLocalNotification.sessionID) else {
                throw LocalNotificationProcessError.unknownSession
            }
            
            guard response.notification.request.content.body == verifiedLocalNotification.alertText else {
                throw LocalNotificationProcessError.mismatchingAlertBody
            }
            
            
            // user didn't select option, simply opened the app with the notification
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                try TransportControl.shared.handle(medium: .remoteNotification, with: verifiedLocalNotification.request, for: session, completionHandler: completionHandler)
                return
            }
            
            // otherwise, process the action
            handleAuthenticatedRequestAction(session: session,
                                             request: verifiedLocalNotification.request,
                                             identifier: response.actionIdentifier,
                                             completionHandler: completionHandler)
            
        } catch {
            log("error processing notification: \(error)", .error)
            completionHandler()
        }
    }
    
    
    func handleAuthenticatedRequestAction(session: Session, request: Request, identifier:String, completionHandler:@escaping ()->Void) {
        // remove pending if exists
        Policy.removePendingAuthorization(session: session, request: request)
        
        guard let action = Policy.Action(rawValue: identifier)
            else {
                log("nil identifier", .error)
                try? Silo.shared().removePending(request: request, for: session)
                try? TransportControl.shared.handle(medium: .remoteNotification, with: request, for: session)
                completionHandler()
                return
        }
        
        let allowed = action.isAllowed
        
        let policySession = Policy.SessionSettings(for: session)
        
        switch action {
        case .approve:
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "once")
        
        case .temporaryThis:
            guard case .ssh(let signRequest) = request.body, let userAndHost = signRequest.verifiedUserAndHostAuth else {
                // error can't temporarily approve this host
                log("cannot temporarily approve request: \(request)", .error)
                break
            }
            policySession.allowThis(userAndHost: userAndHost, for: Policy.Interval.threeHours.seconds)
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve this", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))
            
        case .temporaryAll:
            policySession.allowAll(request: request, for: Policy.Interval.threeHours.seconds)
            
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))
            
        case .reject:
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background reject")
        }
        
        
        do {
            let resp = try Silo.shared().lockResponseFor(request: request, session: session, allowed: allowed)
            try TransportControl.shared.send(resp, for: session, completionHandler: completionHandler)
            
            if let errorMessage = resp.body.error {
                Notify.shared.presentError(message: errorMessage, session: session)
            }
            
        } catch (let e) {
            log("handle error \(e)", .error)
            completionHandler()
            return
        }
    }

}
