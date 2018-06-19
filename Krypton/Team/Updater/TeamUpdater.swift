//
//  TeamUpdater.swift
//  Krypton
//
//  Created by Alex Grinman on 8/7/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TeamUpdater {
    
    static let mutex = Mutex()

    // 10m
    static var checkInterval = TimeSeconds.minute.multiplied(by: 10)
    
    static private let storageKey = "hashchain_update_last_checked"
    
    internal class var lastChecked:Date? {
        get {
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
    
    class func shouldCheckTimed() -> Bool {
        defer { mutex.unlock() }
        mutex.lock()

        guard let last = TeamUpdater.lastChecked else {
            return true
        }
        
        return abs(last.timeIntervalSinceNow) > TeamUpdater.checkInterval

    }
    class func shouldCheck(for request:Request) -> Bool{
        switch request.body {
        case .teamOperation:
            // force a check
            return true
            
        case .ssh, .git, .hosts, .me, .noOp, .unpair, .decryptLog, .readTeam, .u2fRegister, .u2fAuthenticate:
            return shouldCheckTimed()
        }
    }
    
    class func checkForUpdate(completionHandler:@escaping ((_ didUpdate:Bool) ->Void)) {
        guard   let hasTeam = try? IdentityManager.hasTeam(),
                    hasTeam
        else {
            log("no team...skipping team update")
            completionHandler(false)
            return
        }
        
        log("checking for hash chain updates...")
        
        dispatchAsync {            
            var result = false

            do {
                let response = try TeamService.shared().getVerifiedTeamUpdatesSync()
                
                self.mutex.lock {
                    TeamUpdater.lastChecked = Date()
                }
                
                switch response {
                case .error(let e):
                    throw e
                    
                case .result(let service):
                    do {
                        try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                        result = true
                    } catch {
                        log("error saving team: \(error)", .error)
                    }
                }
            } catch {
                log("error trying to update team: \(error)", .error)
            }

            completionHandler(result)

        }
        
    }
    

}
