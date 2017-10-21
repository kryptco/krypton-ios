//
//  AppDelegate+Notification.swift
//  Kryptonite
//
//  Created by Remi Robert on 21/10/2017.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit

extension AppDelegate {
    
    //MARK: Registering Notifications
    
    func registerPushNotifications() {
        DispatchQueue.main.async {
            let settings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: [Policy.authorizeCategory])
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
    }

    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        if notificationSettings.types != UIUserNotificationType() {
            application.registerForRemoteNotifications()
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let chars = deviceToken.bytes
        var token = ""

        for i in 0..<deviceToken.count {
            token += String(format: "%02.2hhx", arguments: [chars[i]])
        }

        log("Got token: \(token)")

        API().updateSNS(token: token) { (endpoint, err) in
            guard let arn = endpoint else {
                log("AWS SNS error: \(String(describing: err))", .error)
                return
            }

            do {
                try KeychainStorage().set(key: KR_ENDPOINT_ARN_KEY, value: arn)
            } catch {
                log("Could not save push ARN", .error)
            }

            API().setEndpointEnabledSNS(endpointArn: arn, completionHandler: { (err) in
                if let err = err {
                    log("AWS SNS endpoint enable error: \(err)", .error)
                    return
                }
            })
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {

        log("Push registration failed!", .error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {

        self.application(application, didReceiveRemoteNotification: userInfo) { (fr) in
            log("handled from other didReceive")
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {

        log("got background notification")


        if let _ = (userInfo["aps"] as? [String: Any])?["mutable-content"], #available(iOS 10.0, *) {
            log("remote notififcation background handler called, but iOS 10. Ignoring.")
            completionHandler(.noData)
            return
        }

        checkForAppUpdateIfNeededBackground()

        guard   let queue = (userInfo["aps"] as? [String: Any])?["queue"] as? QueueName,
            let networkMessageString = (userInfo["aps"] as? [String: Any])?["c"] as? String
            else {
                log("invalid push notification: \(userInfo)", .error)
                completionHandler(.failed)
                return
        }

        guard let session = SessionManager.shared.all.filter({ $0.pairing.queue == queue }).first else {
            log("no session for queue name: \(queue)", .error)
            completionHandler(.failed)
            return

        }

        do {
            let networkMessage = try NetworkMessage(networkData: networkMessageString.fromBase64())
            let req = try Request(from: session.pairing, sealed: networkMessage.data)

            try TransportControl.shared.handle(medium: .remoteNotification, with: req, for: session, completionHandler: {
                completionHandler(.newData)
            })

        } catch let e {
            log("error creating or sending response: \(e)")
            completionHandler(.failed)
        }
    }

    //MARK: Tap local notification
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        log("local notification")
        handleNotification(userInfo: notification.userInfo)
    }

    func handleNotification(userInfo:[AnyHashable : Any]?) {
        if
            let sessionID = userInfo?["session_id"] as? String,
            let session = SessionManager.shared.get(id: sessionID),
            let requestObject = userInfo?["request"] as? [String:Any],
            let request = try? Request(json: requestObject)

        {
            // if approval notification
            do {
                try TransportControl.shared.handle(medium: .remoteNotification, with: request, for: session)
            } catch {
                log("handle failed \(error)", .error)
            }
        }

    }

    //MARK: Allow/Reject

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {

        handleAction(userInfo: notification.userInfo, identifier: identifier, completionHandler: completionHandler)
    }

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {

        handleAction(userInfo: userInfo, identifier: identifier, completionHandler: completionHandler)
    }

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {

        handleAction(userInfo: userInfo, identifier: identifier, completionHandler: completionHandler)

    }

    func application(_ application: UIApplication,
                     handleActionWithIdentifier identifier: String?,
                     for notification: UILocalNotification,
                     completionHandler: @escaping () -> Void ){

        handleAction(userInfo: notification.userInfo, identifier: identifier, completionHandler: completionHandler)

    }

    // UNUserNotificationCenterDelegate
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,withCompletionHandler completionHandler: @escaping () -> Void) {

        handleAction(userInfo: response.notification.request.content.userInfo, identifier: response.actionIdentifier, completionHandler: completionHandler)
    }


    func handleAction(userInfo:[AnyHashable : Any]?, identifier:String?, completionHandler:@escaping ()->Void) {

        if let (session, request) = try? convertLocalJSONAction(userInfo: userInfo) {
            handleRequestAction(session: session, request: request, identifier: identifier, completionHandler: completionHandler)
        } else if let (session, request) = try? unsealUntrustedAction(userInfo: userInfo) {
            handleRequestAction(session: session, request: request, identifier: identifier, completionHandler: completionHandler)
        } else {
            log("invalid notification", .error)
            completionHandler()
        }
    }

    func unsealUntrustedAction(userInfo:[AnyHashable : Any]?) throws -> (Session,Request) {
        guard let notificationDict = userInfo?["aps"] as? [String:Any],
            let ciphertextB64 = notificationDict["c"] as? String,
            let ciphertext = try? ciphertextB64.fromBase64(),
            let sessionUUID = notificationDict["session_uuid"] as? String,
            let session = SessionManager.shared.get(queue: sessionUUID),
            let alert = notificationDict["alert"] as? String,
            alert == "Kryptonite Request"
            else {
                log("invalid untrusted encrypted notification", .error)
                throw InvalidNotification()
        }
        let sealed = try NetworkMessage(networkData: ciphertext).data
        let request = try Request(from: session.pairing, sealed: sealed)
        return (session, request)
    }

    func convertLocalJSONAction(userInfo:[AnyHashable : Any]?) throws -> (Session,Request) {
        guard let sessionID = userInfo?["session_id"] as? String,
            let session = SessionManager.shared.get(id: sessionID),
            let requestObject = userInfo?["request"] as? [String:Any]
            else {
                log("invalid notification", .error)
                throw InvalidNotification()
        }
        return try (session, Request(json: requestObject))
    }

    func handleRequestAction(session: Session, request: Request, identifier:String?, completionHandler:@escaping ()->Void) {
        // remove pending if exists
        Policy.removePendingAuthorization(session: session, request: request)

        guard let identifier = identifier, let actionIdentifier = Policy.ActionIdentifier(rawValue: identifier)
            else {
                log("nil identifier", .error)
                Silo.shared.removePending(request: request, for: session)
                try? TransportControl.shared.handle(medium: .remoteNotification, with: request, for: session)
                completionHandler()
                return
        }

        let signatureAllowed = (identifier == Policy.approveAction.identifier || identifier == Policy.approveTemporaryAction.identifier)

        switch actionIdentifier {
        case Policy.ActionIdentifier.approve:
            Policy.set(needsUserApproval: true, for: session) // override setting incase app terminated
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "once")

        case Policy.ActionIdentifier.temporary:
            Policy.allow(session: session, for: Policy.Interval.threeHours)
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background approve", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))

        case Policy.ActionIdentifier.reject:
            Policy.set(needsUserApproval: true, for: session) // override setting incase app terminated
            Analytics.postEvent(category: request.body.analyticsCategory, action: "background reject")

        }


        do {
            let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: signatureAllowed)
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
