//
//  IdentityManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/24/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class IdentityManager {
    
    private static let mutex = Mutex()

    enum Storage:String {
        case defaultIdentity = "kr_me_email"
        case teamIdentity = "team_identity"
        
        var key:String { return self.rawValue }
    }

    
    /**
        Me - create and get the default identity
     */
    class func getMe() throws -> String {
        mutex.lock()
        defer { mutex.unlock() }
        
        return try KeychainStorage().get(key: Storage.defaultIdentity.key)
    }
    
    class func setMe(email:String) {
        mutex.lock {
            do {
                try KeychainStorage().set(key: Storage.defaultIdentity.key, value: email)
            } catch {
                log("failed to store `me` email: \(error)", .error)
            }
            
            dispatchAsync { Analytics.sendEmailToTeamsIfNeeded(email: email) }
        }
    }
    
    class func clearMe() {
        mutex.lock()
        defer { mutex.unlock() }
        
        do {
            try KeychainStorage().delete(key: Storage.defaultIdentity.key)
        } catch {
            log("failed to delete `me` email: \(error)", .error)
        }
    }
    
    /**
        Team - create and get the team identity
     */
    private static var teamIdentity:TeamIdentity?
    
    class func getTeamIdentity() throws -> TeamIdentity? {
        mutex.lock()
        defer { mutex.unlock() }
        
        if let identity = teamIdentity {
            return identity
        }
        
        do {
            let teamIdData = try KeychainStorage().getData(key: Storage.teamIdentity.key)
            teamIdentity = try TeamIdentity(jsonData: teamIdData)
            return teamIdentity
        } catch KeychainStorageError.notFound {
            return nil
        }
        
    }
    
    class func hasTeam() -> Bool {
        do {
            let teamIdentity = try IdentityManager.getTeamIdentity()
            return teamIdentity != nil
        } catch  {
            return false
        }
    }
    
    class func setTeamIdentity(identity:TeamIdentity) throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        do {
            // save the team data
            try identity.dataManager.saveContext()

            // save the identity to keychain
            try KeychainStorage().setData(key: Storage.teamIdentity.key, data: identity.jsonData())
            
            // set the shared teamIdentity
            teamIdentity = identity
            
        } catch {
            identity.dataManager.rollbackContext()
            
            throw error
        }
        
        // notify policy that rules may have changed
        Policy.teamDidUpdate()
    }
    
    class func commitTeamChanges(identity:TeamIdentity) throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        let previousTeamIdentity = teamIdentity
        
        do {
            // update team data
            try identity.dataManager.saveContext()
            teamIdentity?.team = identity.team
            teamIdentity?.dataManager = identity.dataManager

            // update the checkpoint
            if let blockHash = identity.team.lastBlockHash {
                teamIdentity?.checkpoint = blockHash
            }
            
            // save the identity to keychain
            if let identity = teamIdentity {
                try KeychainStorage().setData(key: Storage.teamIdentity.key, data: identity.jsonData())
            }

            
        } catch {
            identity.dataManager.rollbackContext()
            teamIdentity = previousTeamIdentity
            
            throw error
        }
        
        // notify policy that rules may have changed
        Policy.teamDidUpdate()
    }
    
    class func removeTeamIdentity() throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        try KeychainStorage().delete(key: Storage.teamIdentity.key)
        teamIdentity = nil
        
        Policy.teamDidUpdate()
    }

}
