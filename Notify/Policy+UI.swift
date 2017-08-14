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
    class func requestUserAuthorization(session:Session, request:Request) {}
    class func notifyUser(session:Session, request:Request) {}
    class func notifyUser(errorMessage:String, session:Session) {}
    class func refreshPushNotificationRegistration() {}
}
