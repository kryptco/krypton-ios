//
//  AppDelegate+Background.swift
//  Kryptonite
//
//  Created by Remi Robert on 21/10/2017.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit

extension AppDelegate {

    //MARK: Update Checking in the Background
    
    func checkForAppUpdateIfNeededBackground() {
        Updater.checkForUpdateIfNeeded { (version) in
            guard let newVersion = version else {
                log("no new version found")
                return
            }

            let notification = UILocalNotification()
            notification.alertBody = "A new version of Kryptonite (v\(newVersion.string)) is now available!"
            notification.soundName = UILocalNotificationDefaultSoundName
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
}
