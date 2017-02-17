//
//  NotificationService.swift
//  Notify
//
//  Created by Alex Grinman on 12/15/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    struct InvalidRemoteNotification:Error{}

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent
        else {
            return
        }
        
        
        do {
            let (session, unsealedRequest) = try unsealRemoteNotification(userInfo: bestAttemptContent.userInfo)

            bestAttemptContent.body = "Request from \(session.pairing.displayName): \(unsealedRequest.sign?.command ?? "SSH login")"
            bestAttemptContent.userInfo = ["session_id": session.id, "request": unsealedRequest.object]
            contentHandler(bestAttemptContent)
        } catch {
            log("error: \(error), session count: \(SessionManager.shared.all.count), user info: \(bestAttemptContent.userInfo)")
        }

    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    
    func unsealRemoteNotification(userInfo:[AnyHashable : Any]?) throws -> (Session,Request) {
        
        guard let notificationDict = userInfo?["aps"] as? [String:Any],
            let ciphertextB64 = notificationDict["c"] as? String,
            let ciphertext = try? ciphertextB64.fromBase64(),
            let sessionUUID = notificationDict["session_uuid"] as? String,
            let session = SessionManager.shared.get(queue: sessionUUID)
        else {
            log("invalid untrusted encrypted notification", .error)
            throw InvalidRemoteNotification()
        }
        let sealed = try NetworkMessage(networkData: ciphertext).data
        let request = try Request(key: session.pairing.symmetricKey, sealed: sealed)
        return (session, request)
    }


}
