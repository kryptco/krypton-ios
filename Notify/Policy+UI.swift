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
        NotificationService.shared?.alertTitle = "Request from \(session.pairing.displayName) *"
        NotificationService.shared?.approved = false

    }
    
    class func notifyUser(session:Session, request:Request) {
        NotificationService.shared?.alertTitle = "Approved request from \(session.pairing.displayName) *"
        NotificationService.shared?.approved = true
    }
}
