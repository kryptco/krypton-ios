//
//  Policy+UI.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UserNotifications
import JSON

extension Policy {
    class func requestUserAuthorization(session:Session, request:Request) {
        NotificationService.shared?.bestAttemptContent?.title = "Request from \(session.pairing.displayName) *"
        NotificationService.shared?.bestAttemptContent?.body = "\(request.sign?.display ?? "SSH login")"
        NotificationService.shared?.bestAttemptContent?.userInfo = ["session_id": session.id, "request": request.object]
        NotificationService.shared?.bestAttemptContent?.sound = UNNotificationSound.default()
    }
    
    class func notifyUser(session:Session, request:Request) {
        NotificationService.shared?.bestAttemptContent?.title = "Request from \(session.pairing.displayName) approved *"
        NotificationService.shared?.bestAttemptContent?.body = "\(request.sign?.display ?? "SSH login")"
        NotificationService.shared?.bestAttemptContent?.userInfo = ["session_id": session.id, "request": request.object]
        NotificationService.shared?.bestAttemptContent?.sound = UNNotificationSound.default()
        NotificationService.shared?.bestAttemptContent?.categoryIdentifier  = ""
    }
}
