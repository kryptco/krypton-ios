//
//  KeyManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import PGPFormat

class KeyManager {
    
    var keyPair:KeyPair
    
    enum Storage:String {
        case tag = "me"
        case defaultIdentity = "kr_me_email"
        case teamIdentity = "team_identity"
        
        var key:String { return self.rawValue }
    }
    
    init(_ keyPair:KeyPair) {
        self.keyPair = keyPair
    }
    
    private static let meKey = "kr_me_email"

    enum Errors:Error {
        case keyDoesNotExist
    }
    
    class func sharedInstance() throws -> KeyManager {
        do {
            if let rsaKP = try RSAKeyPair.load(Storage.tag.key) {
                return KeyManager(rsaKP)
            }
            else if let edKP = try Ed25519KeyPair.load(Storage.tag.key) {
                return KeyManager(edKP)
            }
            else {
                throw Errors.keyDoesNotExist
            }                        
        }
        catch let e {
            log("Crypto Load error -> \(e)", LogType.warning)
            throw e
        }
    }

    class func generateKeyPair(type:KeyType) throws {
        do {
            switch type {
            case .RSA:
                let _ = try RSAKeyPair.generate(Storage.tag.key)
            case .Ed25519:
                let _ = try Ed25519KeyPair.generate(Storage.tag.key)
            }
        }
        catch let e {
            log("Crypto Generate error -> \(e)", LogType.warning)
            throw e
        }
    }
    
    class func destroyKeyPair() {
        
        // destroy rsa
        do {
            try RSAKeyPair.destroy(Storage.tag.key)
        } catch {
            log("failed to destroy RSA Keypair: \(error)")
        }
        
        // destroy ed
        do {
            try Ed25519KeyPair.destroy(Storage.tag.key)
        } catch {
            log("failed to destroy Ed25519 Keypair: \(error)")
        }
        
        // destroy PGP public entities
        do {
            try KeychainStorage().delete(key: PGPPublicKeyStorage.created.key(tag: Storage.tag.key))
        } catch {
            log("failed to destroy PGP created date: \(error)")
        }
        
        do {
            try KeychainStorage().delete(key: PGPPublicKeyStorage.userIDs.key(tag: Storage.tag.key))
        } catch {
            log("failed to destroy PGP userIDs: \(error)")
        }
    }
    
    class func hasKey() -> Bool {
        do {
            if let _ = try RSAKeyPair.load(Storage.tag.key) {
                log("has rsa key is true")
                return true
            } else if let _ = try Ed25519KeyPair.load(Storage.tag.key) {
                log("has ed25519 key is true")
                return true
            }

        } catch {}

        return false
    }
    
    /** 
        Me - create and get the default identity
     */
    class func getMe() throws -> String {
        return try KeychainStorage().get(key: Storage.defaultIdentity.key)
    }
    
    class func setMe(email:String) {
        do {
            try KeychainStorage().set(key: Storage.defaultIdentity.key, value: email)
        } catch {
            log("failed to store `me` email: \(error)", .error)
        }
        
        dispatchAsync { Analytics.sendEmailToTeamsIfNeeded(email: email) }
    }
    
    class func clearMe() {
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
        do {
            let teamIdData = try KeychainStorage().getData(key: Storage.teamIdentity.key)
            return try TeamIdentity(jsonData: teamIdData)
        } catch KeychainStorageError.notFound {
            return nil
        }

    }
    
    class func setTeam(identity:TeamIdentity) throws {
        try KeychainStorage().setData(key: Storage.teamIdentity.key, data: identity.jsonData())
    }
    
    class func removeTeamIdentity() throws {
        try KeychainStorage().delete(key: Storage.teamIdentity.key)
    }
}

/**
    Extend KeyManager to pull out the same self-signed PGP Public Key
    for the current keypair.
 */

enum PGPPublicKeyStorage:String {
    case created         = "created"
    case userIDs         = "userid-list"
    
    func key(tag:String) -> String {
        return "pgp.pub.\(tag).\(self.rawValue)"
    }
}
extension KeyManager {
    
    func loadPGPPublicKey(for identity:String) throws -> AsciiArmorMessage {
        
        // get and update userid list if needed
        let userIds = self.updatePGPUserIDPreferences(for: identity)
        
        // get the created time or instantiate it and save it
        var created:Date
        do {
            guard let savedCreated = Double(try KeychainStorage().get(key: PGPPublicKeyStorage.created.key(tag: Storage.tag.key)))
                else {
                    throw KeychainStorageError.notFound
            }
            
            created = Date(timeIntervalSince1970: savedCreated)
            
        } catch KeychainStorageError.notFound {
            
            // shift to 15m ago to avoid clock skew errors of a "future" key
            created = Date().shifted(by: -Properties.allowedClockSkew)
            
            try KeychainStorage().set(key: PGPPublicKeyStorage.created.key(tag: Storage.tag.key), value: "\(created.timeIntervalSince1970)")
            
            log("Set the PGP public key created date to: \(created)", .warning)
        }
        
        // sign the public key and return it
        return try self.keyPair.exportAsciiArmoredPGPPublicKey(for: userIds, created: created)
    }
    
    var pgpUserIDs:[String] {
        let userIdList = (try? UserIDList(jsonString: KeychainStorage().get(key: PGPPublicKeyStorage.userIDs.key(tag: Storage.tag.key)))) ?? UserIDList.empty
        return userIdList.ids
    }

    func updatePGPUserIDPreferences(for identity:String) -> [String] {
        
        var userIdList = (try? UserIDList(jsonString: KeychainStorage().get(key: PGPPublicKeyStorage.userIDs.key(tag: Storage.tag.key)))) ?? UserIDList.empty
        
        // add new identity
        userIdList = userIdList.by(updating: identity)

        do {
            try KeychainStorage().set(key: PGPPublicKeyStorage.userIDs.key(tag: Storage.tag.key), value: userIdList.jsonString())
            return userIdList.ids
            
        } catch {
            log("could not save pgp identity to keychain: \(error)", .error)
            return userIdList.ids
        }
    }
    
    func getPGPPublicKeyID() throws -> Data {
        
        // get the created time
        guard let pgpPublicKeyCreated = Double(try KeychainStorage().get(key: PGPPublicKeyStorage.created.key(tag: Storage.tag.key)))
        else {
            throw KeychainStorageError.notFound
        }
        
        let created = Date(timeIntervalSince1970: pgpPublicKeyCreated)

        let pgpPublicKey = try PGPFormat.PublicKey(create: self.keyPair.publicKey.type.pgpKeyType, publicKeyData: self.keyPair.publicKey.pgpPublicKey(), date: created)

        return try pgpPublicKey.keyID()
    }
}


