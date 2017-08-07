//
//  Updater.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/25/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

class Updater {
    
    static let mutex = Mutex()
    
    class var lastChecked:Date? {
        get {
            return UserDefaults.group?.object(forKey: "update_last_checked") as? Date
        } set (d) {
            mutex.lock {
                if let date = d {
                    UserDefaults.group?.set(date, forKey: "update_last_checked")
                } else {
                    UserDefaults.group?.removeObject(forKey: "update_last_checked")
                }
                UserDefaults.group?.synchronize()
            }
        }
    }
    
    class var shouldCheck:Bool {
        guard let last = Updater.lastChecked else {
            return true
        }
        
        switch UIApplication.shared.applicationState {
        case .active:
            return abs(last.timeIntervalSinceNow) > Properties.AppUpdateCheckInterval.foreground
        default:
            return abs(last.timeIntervalSinceNow) > Properties.AppUpdateCheckInterval.background
        }        
    }
    
    class func checkForUpdateIfNeeded(completionHandler:@escaping ((Version?)->Void)) {
        guard Updater.shouldCheck else {
            completionHandler(nil)
            return
        }
        
        log("checking for new version...")

        API().getNewestAppVersion { (version, err) in
            guard let remoteVersion = version else {
                log("could not get remote version: \(String(describing: err))", .error)
                return
            }
            
            Updater.lastChecked = Date()
          
            if remoteVersion > Properties.currentVersion {
                completionHandler(remoteVersion)
            } else {
                completionHandler(nil)
            }
        }
    }
    
}
