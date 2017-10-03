//
//  IdentityManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/24/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

class IdentityManager {
    
    private static let mutex = Mutex()

    enum Storage:String {
        case defaultIdentity = "kr_me_email"
        case immutableTeamIdentity = "kr_team_identity"
        case mutableTeamIdentity = "kr_mut_team_identity"
        
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
    
    class func getTeamIdentity() throws -> TeamIdentity? {
        mutex.lock()
        defer { mutex.unlock() }
        
        do {
            // parse the immutable team data
            var teamObject:Object = try JSON.parse(data: KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).getData(key: Storage.immutableTeamIdentity.key))
            
            // parse the mutable
            let mutableTeamObject:Object = try JSON.parse(data: KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).getData(key: Storage.mutableTeamIdentity.key))

            teamObject["mutable_data"] = mutableTeamObject
            
            // init the TeamIdentity with all the data
            return try TeamIdentity(json: teamObject)
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
            
            // get the immutable + mutable parts of the team identity
            let identityData = try identity.jsonData()
            let mutableTeamData = try identity.mutableData.jsonData()
            
            // save the both parts to keychain
            try KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).setData(key: Storage.immutableTeamIdentity.key, data: identityData)
            
            try KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).setData(key: Storage.mutableTeamIdentity.key, data: mutableTeamData)
            
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
        
        do {
            // update team data
            try identity.dataManager.saveContext()

            // update the mutable identity data
            var mutableData = identity.mutableData
            
            if let blockHash = try identity.lastBlockHash() {
                mutableData.checkpoint = blockHash
            }
            
            // save the identity to keychain
            try KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).setData(key: Storage.mutableTeamIdentity.key, data: mutableData.jsonData())

            
        } catch {
            identity.dataManager.rollbackContext()
            throw error
        }
        
        // notify policy that rules may have changed
        Policy.teamDidUpdate()
    }
    
    class func removeTeamIdentity() throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        try KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).delete(key: Storage.immutableTeamIdentity.key)
        
        try KeychainStorage(service: Constants.teamKeyChainService, accessGroup: true).delete(key: Storage.mutableTeamIdentity.key)

        Policy.teamDidUpdate()
    }

}
