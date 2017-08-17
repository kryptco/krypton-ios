//
//  HashChain+Update.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/7/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class HashChainUpdater {
    
    static let mutex = Mutex()
    
    static var checkInterval = TimeSeconds.minute.multiplied(by: 5)
    
    static private let storageKey = "hashchain_update_last_checked"
    
    class var lastChecked:Date? {
        get {
            return UserDefaults.group?.object(forKey: storageKey) as? Date
        } set (d) {
            mutex.lock {
                if let date = d {
                    UserDefaults.group?.set(date, forKey: storageKey)
                } else {
                    UserDefaults.group?.removeObject(forKey: storageKey)
                }
                UserDefaults.group?.synchronize()
            }
        }
    }
    
    class var shouldCheck:Bool {
        guard let last = HashChainUpdater.lastChecked else {
            return true
        }
        
        return abs(last.timeIntervalSinceNow) > HashChainUpdater.checkInterval
    }
    
    class func checkForUpdate(completionHandler:@escaping ((_ didUpdate:Bool) ->Void)) {
        mutex.lock()
        
        guard let teamIdentity = (try? KeyManager.getTeamIdentity()) as? TeamIdentity else {
            log("no team...skipping team update")
            mutex.unlock()
            completionHandler(false)
            return
        }
        
        log("checking for hash chain updates on \(teamIdentity.team.info.name)...")
        
        do {
            try HashChainService(teamIdentity: teamIdentity).getVerifiedTeamUpdates { (response) in
                
                HashChainUpdater.lastChecked = Date()
                
                mutex.unlock()

                switch response {
                case .error(let e):
                    log("error updating team: \(e)", .error)
                    completionHandler(false)
                    
                case .result(let updatedTeam):
                    var updatedIdentity = teamIdentity
                    updatedIdentity.team = updatedTeam
                    
                    try? KeyManager.setTeam(identity: updatedIdentity)
                    
                    completionHandler(true)
                }
            }
        } catch {
            log("error trying to update team: \(error)", .error)
            mutex.unlock()
            completionHandler(false)
        }
    }
    
}
