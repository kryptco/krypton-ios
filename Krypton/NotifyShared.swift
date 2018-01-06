//
//  NotifyShared.swift
//  Krypton
//
//  Created by Alex Grinman on 11/14/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UserNotifications

class NotifyShared {
    
    static func appDataProtectionNotAvailableError() -> UNNotificationContent {
        let content = appErrorNotificationContent(title: "\(Properties.appName) Locked",
                                                               error: "\(Properties.appName) cannot be used before the device has been unlocked for the first time. Please unlock your device and try again.")
        return content
    }

    
    /// Create an app error notification content message
    static func appErrorNotificationContent(title:String, error:String) -> UNNotificationContent {
        let noteTitle = title
        let noteBody = error
        
        let content = UNMutableNotificationContent()
        content.title = noteTitle
        content.body = noteBody
        content.sound = UNNotificationSound.default()
        
        return content
    }
}
