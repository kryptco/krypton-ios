//
//  KeyManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import PGPFormat

enum KeyTag:String {
    case me = "me"
}

private let KrMeDataKey = "kr_me_email"

enum KeyManagerError:Error {
    case keyDoesNotExist
}

class KeyManager {
    
    var keyPair:KeyPair
    
    init(_ keyPair:KeyPair) {
        self.keyPair = keyPair
    }
    
    class func sharedInstance() throws -> KeyManager {
        do {
            if let rsaKP = try RSAKeyPair.load(KeyTag.me.rawValue) {
                return KeyManager(rsaKP)
            }
            else if let edKP = try Ed25519KeyPair.load(KeyTag.me.rawValue) {
                return KeyManager(edKP)
            }
            else {
                throw KeyManagerError.keyDoesNotExist
            }
            

            /*let loadStart = Date().timeIntervalSince1970
            let loadEnd = Date().timeIntervalSince1970
            log("keypair load took \(loadEnd - loadStart) seconds")*/
            
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
                let _ = try RSAKeyPair.generate(KeyTag.me.rawValue)
            case .Ed25519:
                let _ = try Ed25519KeyPair.generate(KeyTag.me.rawValue)
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
            try RSAKeyPair.destroy(KeyTag.me.rawValue)
        } catch {
            log("failed to destroy RSA Keypair: \(error)")
        }
        
        // destroy ed
        do {
            try Ed25519KeyPair.destroy(KeyTag.me.rawValue)
        } catch {
            log("failed to destroy Ed25519 Keypair: \(error)")
        }
        
        // destroy PGP public entities
        do {
            try KeychainStorage().delete(key: PGPPublicKeyStorage.created.key(tag: KeyTag.me))
        } catch {
            log("failed to destroy PGP created date: \(error)")
        }
        
        do {
            try KeychainStorage().delete(key: PGPPublicKeyStorage.userIDs.key(tag: KeyTag.me))
        } catch {
            log("failed to destroy PGP userIDs: \(error)")
        }
    }
    
    class func hasKey() -> Bool {
        do {
            if let _ = try RSAKeyPair.load(KeyTag.me.rawValue) {
                log("has rsa key is true")
                return true
            } else if let _ = try Ed25519KeyPair.load(KeyTag.me.rawValue) {
                log("has ed25519 key is true")
                return true
            }

        } catch {}

        return false
    }
    
    func getMe() throws -> String {
        return try KeychainStorage().get(key: KrMeDataKey)
    }
    
    class func setMe(email:String) {
        do {
            try KeychainStorage().set(key: KrMeDataKey, value: email)
        } catch {
            log("failed to store `me` email: \(error)", .error)
        }
        
        dispatchAsync { Analytics.sendEmailToTeamsIfNeeded(email: email) }
    }
    
    class func clearMe() {
        do {
            try KeychainStorage().delete(key: KrMeDataKey)
        } catch {
            log("failed to delete `me` email: \(error)", .error)
        }
    }
    
}

/**
    Extend KeyManager and KeyTag to pull out the same self-signed PGP Public Key
    for the current keypair.
 */

extension KeyTag {
    var publicPGPStorageKey:String {
        return "pgpkey.public.\(self.rawValue)"
    }
}

enum PGPPublicKeyStorage:String {
    case created         = "created"
    case userIDs         = "userid-list"
    
    func key(tag:KeyTag) -> String {
        return "pgp.pub.\(tag.rawValue).\(self.rawValue)"
    }
}
extension KeyManager {
    
    func loadPGPPublicKey(for identity:String) throws -> AsciiArmorMessage {
        
        // get and update userid list if needed
        let userIds = self.updatePGPUserIDPreferences(for: identity)
        
        // get the created time or instantiate it and save it
        var created:Date
        do {
            guard let savedCreated = Double(try KeychainStorage().get(key: PGPPublicKeyStorage.created.key(tag: .me)))
                else {
                    throw KeychainStorageError.notFound
            }
            
            created = Date(timeIntervalSince1970: savedCreated)
            
        } catch KeychainStorageError.notFound {
            
            // shift to 15m ago to avoid clock skew errors of a "future" key
            created = Date().shifted(by: -Properties.allowedClockSkew)
            
            try KeychainStorage().set(key: PGPPublicKeyStorage.created.key(tag: .me), value: "\(created.timeIntervalSince1970)")
            
            log("Set the PGP public key created date to: \(created)", .warning)
        }
        
        // sign the public key and return it
        return try self.keyPair.exportAsciiArmoredPGPPublicKey(for: userIds, created: created)
    }
    
    func updatePGPUserIDPreferences(for identity:String) -> [String] {
        
        var userIdList = (try? UserIDList(jsonString: KeychainStorage().get(key: PGPPublicKeyStorage.userIDs.key(tag: .me)))) ?? UserIDList.empty
        
        // add new identity
        userIdList = userIdList.by(updating: identity)

        do {
            try KeychainStorage().set(key: PGPPublicKeyStorage.userIDs.key(tag: .me), value: userIdList.jsonString())
            return userIdList.ids
            
        } catch {
            log("could not save pgp identity to keychain: \(error)", .error)
            return userIdList.ids
        }
    }
    
    func getPGPPublicKeyID() throws -> Data {
        
        // get the created time
        guard let pgpPublicKeyCreated = Double(try KeychainStorage().get(key: PGPPublicKeyStorage.created.key(tag: .me)))
        else {
            throw KeychainStorageError.notFound
        }
        
        let created = Date(timeIntervalSince1970: pgpPublicKeyCreated)

        let pgpPublicKey = try PGPFormat.PublicKey(create: self.keyPair.publicKey.type.pgpKeyType, publicKeyData: self.keyPair.publicKey.pgpPublicKey(), date: created)

        return try pgpPublicKey.keyID()
    }
}


