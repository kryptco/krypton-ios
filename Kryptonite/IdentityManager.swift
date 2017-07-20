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
    lazy var keychain:KeychainStorage = {
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
        
        var ids = try self.keychain.get(key: Storage.identityList.key).components(separatedBy: ",")
        
        // if not a previous known id, index it.
        if !ids.contains(identity.id) {
            ids.append(identity.id)
            try self.keychain.set(key: Storage.identityList.key, value: ids.joined(separator: ","))
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
        
        var identities:[Identity] = []
        
        for id in try self.keychain.get(key: Storage.identityList.key).components(separatedBy: ",") {
            let identity = try Identity(jsonData: self.keychain.getData(key: id))
            identities.append(identity)
        }
        
        return identities
    }
    
    
}






