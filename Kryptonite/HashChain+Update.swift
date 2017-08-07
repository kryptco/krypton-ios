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
    
    class var lastChecked:Date? {
        get {
            return UserDefaults.group?.object(forKey: "hashchain_update_last_checked") as? Date
        } set (d) {
            mutex.lock {
                if let date = d {
                    UserDefaults.group?.set(date, forKey: "hashchain_update_last_checked")
                } else {
                    UserDefaults.group?.removeObject(forKey: "hashchain_update_last_checked")
                }
                UserDefaults.group?.synchronize()
            }
        }
    }
    
    class var shouldCheck:Bool {
        guard let last = HashChainUpdater.lastChecked else {
            return true
        }
        
        switch UIApplication.shared.applicationState {
        case .active:
            return abs(last.timeIntervalSinceNow) > Properties.HashChainUpdateCheckInterval.foreground
        default:
            return abs(last.timeIntervalSinceNow) > Properties.HashChainUpdateCheckInterval.background
        }
    }
    
    class func checkForUpdateIfNeeded(completionHandler:@escaping ((UpdatedTeam?)->Void)) {
        guard HashChainUpdater.shouldCheck else {
            completionHandler(nil)
            return
        }
        
        guard let teamIdentity = (try? KeyManager.getTeamIdentity()) as? TeamIdentity else {
            completionHandler(nil)
            return
        }
        
        log("checking for hash chain updates on \(teamIdentity.team.info.name)...")
        
        do {
            try HashChainService(teamIdentity: teamIdentity).getVerifiedTeamUpdates { (response) in
                switch response {
                case .error(let e):
                    log("error updating team: \(e)", .error)
                    completionHandler(nil)
                case .result(let updatedTeam):
                    completionHandler(updatedTeam)
                }
            }
        } catch {
            log("error trying to update team: \(error)", .error)
        }
        
    }
    
}
