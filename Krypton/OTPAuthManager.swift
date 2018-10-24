//
//  OTPAuthManager.swift
//  Krypton
//
//  Created by Alex Grinman on 9/20/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

class OTPAuthManager {
    
    private static let sharedMutex = Mutex()
    
    private static let otpKeychainService = "krypton_otp_secrets"
    private static let otpIdsStorageKey = "otp_identifier_storage_key"

    static var keychain:KeychainStorage {
        return KeychainStorage(service: otpKeychainService)
    }
    
    static func loadLocked() throws -> [OTPAuth] {
        sharedMutex.lock()
        defer { sharedMutex.unlock() }

        return try load()
    }
    
    private static func load() throws -> [OTPAuth] {
        let otpIds = try loadOtpIDs()
        
        var otpAuths:[OTPAuth] = []
        
        otpIds.forEach {
            do {
                let otpAuth = try OTPAuth(urlString: keychain.get(key: $0))
                otpAuths.append(otpAuth)
            } catch {
                log("error loading: \($0)", .error)
            }
        }
        
        return otpAuths
    }
    
    static func add(otpAuth:OTPAuth) throws {
        sharedMutex.lock()
        defer { sharedMutex.unlock() }
        
        try add(newOTPAuths: [otpAuth])
    }
    
    private static func add(newOTPAuths:[OTPAuth]) throws {
        var currentOTPIds = try Set(loadOtpIDs())
        
        try Set(newOTPAuths).forEach {
            let id = $0.id
            guard currentOTPIds.contains(id) == false else {
                return
            }
            
            try keychain.set(key: id, value: $0.string)
            currentOTPIds.insert(id)
        }
        
        try save(ids: [String](currentOTPIds))
    }
    
    static func remove(otpAuth:OTPAuth) throws {
        sharedMutex.lock()
        defer { sharedMutex.unlock() }
        
        let otpId = otpAuth.id
        try keychain.delete(key: otpId)
        
        var newOtpIDs = try Set(loadOtpIDs())
        newOtpIDs.remove(otpId)
        
        try save(ids: [String](newOtpIDs))
    }
    
    private static func loadOtpIDs() throws -> [String] {
        var listData:Data
        do {
            listData = try keychain.getData(key: otpIdsStorageKey)
        } catch KeychainStorageError.notFound {
            return []
        } catch {
            throw error
        }
        
        return try JSON.parse(data: listData)
    }
    
    private static func save(ids:[String]) throws {
        try keychain.setData(key: otpIdsStorageKey, data: JSONSerialization.data(withJSONObject: ids))
    }
}
