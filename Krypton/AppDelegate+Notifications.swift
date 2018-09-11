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
        
        if Notify.shared.shouldPresentInAppNotification(notification: notification) {
            completionHandler([.alert, .sound])
            return
        }
        
        completionHandler([])
    }
    
    
    // MARK: SILENT NOTIFICATION PROCESSING
    // silent notification
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        log("didReceieveRemoteNotification")

        // new team data
        if  let noteCategory = (userInfo["aps"] as? [String:Any])?["category"] as? String,
            noteCategory == Policy.NotificationCategory.newTeamData.identifier
        {
            TeamUpdater.checkForUpdatesAndNotifyUserIfNeeded { (success) in
                completionHandler( success ? .newData : .noData )
                NotificationCenter.default.post(name: Constants.NotificationType.newTeamsData.name, object: nil)
            }
            
            return
        }
        
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
            
            TransportControl.shared.handle(medium: .silentNotification, with: request, for: session, completionHandler: {
                completionHandler(.newData)
            }, errorHandler: { error in
                log("silent notification, transport error: \(error)", .error)
                completionHandler(.noData)
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
            
            let verifiedLocalNotification = try LocalNotificationAuthority.verifyLocalNotification(with: payload)
            
            guard let session = SessionManager.shared.get(id: verifiedLocalNotification.sessionID) else {
                throw LocalNotificationProcessError.unknownSession
            }
            
            guard response.notification.request.content.body == verifiedLocalNotification.alertText else {
                throw LocalNotificationProcessError.mismatchingAlertBody
            }
            
            
            // user didn't select option, simply opened the app with the notification
            switch response.actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                completionHandler()
                return

            case UNNotificationDefaultActionIdentifier:
                TransportControl.shared.handle(medium: .remoteNotification, with: verifiedLocalNotification.request, for: session, completionHandler: completionHandler, errorHandler: {_ in
                    completionHandler()
                })
                return

            default:
                guard let action = Policy.Action(rawValue: response.actionIdentifier) else {
                    log("unknown action identifier: \(response.actionIdentifier)", .error)
                    completionHandler()
                    return

                }
                
                handleAuthenticatedRequestAction(session: session,
                                                 request: verifiedLocalNotification.request,
                                                 action: action,
                                                 completionHandler: completionHandler)
            }
            
            
            // otherwise, process the action
            
        } catch {
            log("error processing notification: \(error)", .error)
            completionHandler()
        }
    }
    
    
    func handleAuthenticatedRequestAction(session: Session, request: Request, action:Policy.Action, completionHandler:@escaping ()->Void) {
        // remove pending if exists
        Policy.removePendingAuthorization(session: session, request: request)
        
        let allowed = action.isAllowed
        
        let policySession = Policy.SessionSettings(for: session)
        
        switch action {
        case .approve:
            policySession.allow(request: request)
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "once")
        
        case .temporaryThis:
            guard case .ssh(let signRequest) = request.body, let userAndHost = signRequest.verifiedUserAndHostAuth else {
                // error can't temporarily approve this host
                log("cannot temporarily approve request: \(request)", .error)
                break
            }
            policySession.allowThis(userAndHost: userAndHost, for: Policy.temporaryApprovalInterval.value)
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve this", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))
            
        case .temporaryAll:
            policySession.allowAll(request: request, for: Policy.temporaryApprovalInterval.value)
            
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))
        
        case .dontAskAgain:
            policySession.setZeroTouch(enabled: true)
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "zerotouch")

        case .reject:
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background reject")
        }
        

        /// attempt to get new blocks from the notification extension
        /// if they exist
        do {
            var teamIdentity = try IdentityManager.getTeamIdentity()
            try teamIdentity?.syncTeamDatabaseData(from: .notifyExt, to: .mainApp)
        } catch {
            log("error updating from notify extension \(error)", .error)
        }

        do {
            let resp = try Silo.shared().lockResponseFor(request: request, session: session, allowed: allowed)
            try TransportControl.shared.send(resp, for: session, completionHandler: completionHandler)
            
            if let errorMessage = resp.body.error {
                Notify.presentError(message: errorMessage, request: request, session: session)
            }
            
        } catch (let e) {
            log("handle error \(e)", .error)
            completionHandler()
            return
        }
    }

}
