//
//  TeamUpdater+Notify.swift
//  Krypton
//
//  Created by Alex Grinman on 12/8/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension TeamUpdater {
    
    // check for updates
    class func checkForUpdatesAndNotifyUserIfNeeded(completionHandler:@escaping ((_ didUpdate:Bool) ->Void)) {
        dispatchAsync {
            let result = checkForUpdatesAndNotifyUserIfNeededSyncUnlocked()
            
            self.mutex.lock {
                TeamUpdater.lastChecked = Date()
            }
            
            completionHandler(result)
        }

    }
    
    class func checkForUpdatesAndNotifyUserIfNeededSyncUnlocked() -> Bool {
        
        guard let identity:TeamIdentity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity else {
            log("no team...skipping team update")
            return false
        }
        
        log("checking for hash chain updates...")
        
        do {
            
            var currentCheckpoint:Data?
            var wasAdmin:Bool
            
            (currentCheckpoint, wasAdmin) = try identity.dataManager.withTransaction{ return try ($0.lastBlockHash(), $0.isAdmin(for: identity.publicKey)) }
            
            let result = try TeamService.shared().getVerifiedTeamUpdatesSync()
            
            switch result {
            case .error(let e):
                log("error updating team: \(e)", .error)
                return false
                
            case .result(let service):
                guard let current = currentCheckpoint else {
                    return true
                }
                
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)

                
                // fetch new blocks
                try service.teamIdentity.dataManager.withTransaction {
                    let isAdmin = try service.teamIdentity.isAdmin(dataManager: $0)
                    let teamName = try $0.fetchTeam().name

                    let blocks = try $0.fetchBlocks(after: current)
                    
                    for block in blocks {
                        let (subtitle, body) = try service.teamIdentity.getNotificationDetails(for: block, dataManager: $0)
                        
                        dispatchMain {
                            // show note if app is active or user is team admin
                            guard isAdmin || wasAdmin || UIApplication.shared.applicationState == .active else {
                                return
                            }
                            
                            // only show 1 block notification for (presumably the demote block)
                            // for the now demoted member
                            if !isAdmin {
                                wasAdmin = false
                            }
                            
                            Notify.shared.presentNewBlockToAdmin(signedMessage: block,
                                                                 teamName: teamName,
                                                                 subtitle: subtitle,
                                                                 body: body)
                        }
                        
                    }

                }
                
                return true

            }
        } catch {
            log("error trying to update team: \(error)", .error)
            return false
        }
    }
}
