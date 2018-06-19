//
//  U2FAccountManager.swift
//  Krypton
//
//  Created by Alex Grinman on 5/6/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

class U2FAccountManager {
    
    private static let service = "u2f_accounts_service"
    private static let accountsKey = "u2f_accounts_key"

    private static func lastUsedKey(for appID:U2FAppID) -> String {
        return "appIdLastUsedPrefx.\(appID.hash.toBase64(true))"
    }
    private static let mutex = Mutex()
    
    typealias AccountData = [U2FAppID: Account]
    struct Account {
        let app: U2FAppID
    }
    
    private static var keychain:KeychainStorage {
        return KeychainStorage(service: service)
    }
    
    class func add(account: U2FAppID) throws {
        mutex.lock()
        defer { mutex.unlock() }
        
        var accountMap = try getAllAccounts()
        
        guard accountMap[account] == nil else {
            return
        }
        
        // add the new account and save
        accountMap[account] = Account(app: account)
        try save(accountMap: accountMap)
    }
    
    class func updateLastUsed(account: U2FAppID) throws {
        let now = "\(Date().timeIntervalSince1970)"
        try keychain.set(key: lastUsedKey(for: account), value: now)
    }
    
    class func getLastUsed(account: U2FAppID) -> Date? {
        do {
            let secondsString = try keychain.get(key: lastUsedKey(for: account))
            
            if let seconds = Double(secondsString) {
                return Date(timeIntervalSince1970: seconds)
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    private class func getAllAccounts() throws ->  AccountData {
        do {
            let accountData:[String:Object] = try JSON.parse(data: keychain.getData(key: accountsKey))
            
            var accountMap:AccountData = [:]
            try accountData.forEach {
                let account = try Account(json: $1)
                accountMap[account.app] = account
            }
            
            return accountMap
        } catch KeychainStorageError.notFound {
            return [:]
        }
    }
    
    private class func save(accountMap:AccountData) throws {
        var object:Object = [:]
        accountMap.forEach {
            object[$0.key] = $0.value.object
        }
        
        try keychain.setData(key: accountsKey, data: JSON.jsonData(for: object))
    }
    
    class func getAllAccountsLocked() throws  -> [U2FAppID] {
        mutex.lock()
        defer { mutex.unlock() }
        
        return try [U2FAppID](getAllAccounts().keys)
    }
    
    class func getAllKnownAccountsLocked() throws -> [KnownU2FApplication] {
        mutex.lock()
        defer { mutex.unlock() }
        
        var knownAccounts:[KnownU2FApplication] = []
        
        try [U2FAppID](getAllAccounts().keys).forEach {
            guard let known = KnownU2FApplication(for: $0) else {
                return
            }
            
            knownAccounts.append(known)
        }
        
        return knownAccounts
    }
}

extension U2FAccountManager.Account:Jsonable {
    init(json: Object) throws {
        app = try json ~> "app"
    }
    
    var object:Object {
        return ["app": app]
    }
}
