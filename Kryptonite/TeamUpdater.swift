//
//  TeamUpdater.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/7/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TeamUpdater {
    
    static let mutex = Mutex()
    
    static var checkInterval = TimeSeconds.minute.multiplied(by: 5)
    
    static private let storageKey = "hashchain_update_last_checked"
    
    class var lastChecked:Date? {
        get {
            defer { mutex.unlock() }
            mutex.lock()
            return UserDefaults.group?.object(forKey: storageKey) as? Date
        } set (d) {
            if let date = d {
                UserDefaults.group?.set(date, forKey: storageKey)
            } else {
                UserDefaults.group?.removeObject(forKey: storageKey)
            }
            UserDefaults.group?.synchronize()
        }
    }
    
    class var shouldCheck:Bool {
        guard let last = TeamUpdater.lastChecked else {
            return true
        }
        
        return abs(last.timeIntervalSinceNow) > TeamUpdater.checkInterval
    }
    
    class func checkForUpdateIfNeeded(completionHandler:@escaping ((_ didUpdate:Bool) ->Void)) {
        if IdentityManager.hasTeam() && TeamUpdater.shouldCheck {
            checkForUpdate(completionHandler: completionHandler)
        }
    }
    
    class func checkForUpdate(completionHandler:@escaping ((_ didUpdate:Bool) ->Void)) {
        mutex.lock()
        
        guard var teamIdentity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity else {
            log("no team...skipping team update")
            mutex.unlock()
            completionHandler(false)
            return
        }
        
        log("checking for hash chain updates on \(teamIdentity.team.info.name)...")
        
        do {
            try TeamService.shared().getVerifiedTeamUpdates { (response) in
                TeamUpdater.lastChecked = Date()
                
                mutex.unlock()

                switch response {
                case .error(let e):
                    log("error updating team: \(e)", .error)
                    completionHandler(false)
                    
                case .result(let service):
                    teamIdentity = service.teamIdentity
                    
                    do {
                        try teamIdentity.commitTeamChanges()
                        completionHandler(true)
                    } catch {
                        log("error saving team: \(error)", .error)
                        completionHandler(false)
                    }
                    
                }
            }
        } catch {
            log("error trying to update team: \(error)", .error)
            mutex.unlock()
            completionHandler(false)
        }
    }
    
}
