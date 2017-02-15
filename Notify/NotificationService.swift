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

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    
//    func unsealUntrustedAction(userInfo:[AnyHashable : Any]?) throws -> (Session,Request) {
//        guard let notificationDict = userInfo?["aps"] as? [String:Any],
//            let ciphertextB64 = notificationDict["c"] as? String,
//            let ciphertext = try? ciphertextB64.fromBase64(),
//            let sessionUUID = notificationDict["session_uuid"] as? String,
//            let session = Silo.shared.sessionServiceUUIDS[sessionUUID],
//            let alert = notificationDict["alert"] as? String,
//            alert == "Request from ".appending(session.pairing.displayName)
//            else {
//                log("invalid untrusted encrypted notification", .error)
//                throw InvalidNotification()
//        }
//        let sealed = try NetworkMessage(networkData: ciphertext).data
//        let request = try Request(key: session.pairing.symmetricKey, sealed: sealed)
//        return (session, request)
//    }


}
