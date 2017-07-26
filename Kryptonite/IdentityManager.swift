//
//  IdentityManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium

class IdentityManager {
    /**
        Singelton
     */
    private static var sharedManagerMutex = Mutex()
    private static var sharedManager:IdentityManager?
    
    class var shared:IdentityManager {
        sharedManagerMutex.lock()
        defer { sharedManagerMutex.unlock() }
        
        guard let idm = sharedManager else {
            sharedManager = IdentityManager()
            return sharedManager!
        }
        return idm
    }
    
    /**
        Store all data in Keychain for security, reliability, and persistance
     */
    private static let keychainService = "com.kryptco.identity"
    private lazy var keychain:KeychainStorage = {
        return KeychainStorage(service: IdentityManager.keychainService)
    }()

    enum Storage:String {
        case identityList = "id_list"
        
        var key:String {
            return self.rawValue
        }
    }

    enum Errors:Error {
        case doesNotExist
    }
    
    /**
        Get/Set ID list
     */
    private func getIDs() throws -> [String] {
        var ids:[String]
        do {
            ids = try self.keychain.get(key: Storage.identityList.key).components(separatedBy: ",").filter({ $0.isEmpty == false })
        } catch KeychainStorageError.notFound {
            ids = []
        }
        
        return ids
    }
    
    private func set(ids:[String]) throws {
        try self.keychain.set(key: Storage.identityList.key, value: ids.joined(separator: ","))
    }


    /**
        Internal state members
     */
    private var mutex = Mutex()

    
    /**
        Saves a (potentially) new identity
            - if it exists, update it
            - if it's new, add it to id_list and save id
     */
    func save(identity:Identity) throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        var ids = try getIDs()
        
        // if not a previous known id, index it.
        if !ids.contains(identity.id) {
            ids.append(identity.id)
            try set(ids: ids)
        }
        
        // save the updated identity
        try self.keychain.setData(key: identity.id, data: identity.jsonData())
    }

    
    /**
        Returns a list of identities
        Note: requires two Keychain reads:
            1. fetch id list
            2. fetch and serialize each id
     */
    func list() throws -> [Identity] {
        mutex.lock()
        defer { mutex.unlock() }
        
        let ids = try getIDs()
        
        var identities:[Identity] = []
        for id in ids {
            do {
                let identityData = try self.keychain.getData(key: id)
                let identity = try Identity(jsonData: identityData)
                identities.append(identity)
            } catch {
                log("couldn't parse identity data for: \(id) because: \(error)", .error)
            }
        }
        
        return identities
    }
    
    /**
        Returns number of identities
     */
    func count() throws -> Int {
        mutex.lock()
        defer { mutex.unlock() }
        
        return try getIDs().count
    }
    
    /**
        Select the identity that could respond to a `request`
     */
    func selectIdentities(for requestBody:RequestBody) throws -> Identity? {
        let all = try list()
        
        switch requestBody {
        case .noOp, .unpair:
            return nil
        case .me:
            return nil
            
        case .ssh(let signRequest):
            let publicKeyFingerprint = try signRequest.fingerprint.fromBase64()
            
            return try all.filter({
                return try publicKeyFingerprint == KeyManager.sharedInstance(for: $0).keyPair.publicKey.wireFormat().SHA256
            }).first
            
        case .git(let gitSign):
            return try all.filter({
                return try KeyManager.sharedInstance(for: $0).pgpUserIDs.contains(gitSign.userId)
            }).first
        }
    }

    
    /**
     Returns number of identities
     Note: requires two Keychain writes, one read:
         1. fetch id list
         2. remove id from list
         3. remove id object
     */
    func remove(identity:Identity) throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        var ids = try getIDs()

        if let idIndex = ids.index(of: identity.id) {
            ids.remove(at: idIndex)
            try set(ids: ids)
        }
        
        try self.keychain.delete(key: identity.id)
    }
    
    func destroyAll() throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        let ids = try getIDs()
        
        for id in ids {
            try? self.keychain.delete(key: id)
        }
        
        try self.keychain.delete(key: Storage.identityList.key)
    }

}





