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
    var tag:String
    
    init(_ keyPair:KeyPair, tag:String) {
        self.keyPair = keyPair
        self.tag = tag
    }
    
    private static let meKey = "kr_me_email"

    enum Errors:Error {
        case keyDoesNotExist
    }
    
    class func sharedInstance(for keyPointer:IdentityKeyPointer = DefaultIdentity()) throws -> KeyManager {
        do {
            if let rsaKP = try RSAKeyPair.load(keyPointer.tag) {
                return KeyManager(rsaKP, tag: keyPointer.tag)
            }
            else if let edKP = try Ed25519KeyPair.load(keyPointer.tag) {
                return KeyManager(edKP, tag: keyPointer.tag)
            }
            else {
                throw Errors.keyDoesNotExist
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

    class func generateKeyPair(type:KeyType, for keyPointer:IdentityKeyPointer = DefaultIdentity()) throws {
        do {
            switch type {
            case .RSA:
                let _ = try RSAKeyPair.generate(keyPointer.tag)
            case .Ed25519:
                let _ = try Ed25519KeyPair.generate(keyPointer.tag)
            }
        }
        catch let e {
            log("Crypto Generate error -> \(e)", LogType.warning)
            throw e
        }
    }
    
    class func destroyKeyPair(for keyPointer:IdentityKeyPointer = DefaultIdentity()) {
        
        // destroy rsa
        do {
            try RSAKeyPair.destroy(keyPointer.tag)
        } catch {
            log("failed to destroy RSA Keypair: \(error)")
        }
        
        // destroy ed
        do {
            try Ed25519KeyPair.destroy(keyPointer.tag)
        } catch {
            log("failed to destroy Ed25519 Keypair: \(error)")
        }
        
        // destroy PGP public entities
        do {
            try KeychainStorage().delete(key: PGPPublicKeyStorage.created.key(tag: keyPointer.tag))
        } catch {
            log("failed to destroy PGP created date: \(error)")
        }
        
        do {
            try KeychainStorage().delete(key: PGPPublicKeyStorage.userIDs.key(tag: keyPointer.tag))
        } catch {
            log("failed to destroy PGP userIDs: \(error)")
        }
    }
    
    class func hasKey(keyPointer:IdentityKeyPointer = DefaultIdentity()) -> Bool {
        do {
            if let _ = try RSAKeyPair.load(keyPointer.tag) {
                log("has rsa key is true")
                return true
            } else if let _ = try Ed25519KeyPair.load(keyPointer.tag) {
                log("has ed25519 key is true")
                return true
            }

        } catch {}

        return false
    }
    
    func getMe() throws -> String {
        return try KeychainStorage().get(key: KeyManager.meKey)
    }
    
    class func setMe(email:String) {
        do {
            try KeychainStorage().set(key: KeyManager.meKey, value: email)
        } catch {
            log("failed to store `me` email: \(error)", .error)
        }
        
        dispatchAsync { Analytics.sendEmailToTeamsIfNeeded(email: email) }
    }
    
    class func clearMe() {
        do {
            try KeychainStorage().delete(key: KeyManager.meKey)
        } catch {
            log("failed to delete `me` email: \(error)", .error)
        }
    }
    
}

/**
    Extend KeyManager and KeyTag to pull out the same self-signed PGP Public Key
    for the current keypair.
 */

extension IdentityKeyPointer {
    var publicPGPStorageKey:String {
        return "pgpkey.public.\(self.tag)"
    }
}

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
            guard let savedCreated = Double(try KeychainStorage().get(key: PGPPublicKeyStorage.created.key(tag: self.tag)))
                else {
                    throw KeychainStorageError.notFound
            }
            
            created = Date(timeIntervalSince1970: savedCreated)
            
        } catch KeychainStorageError.notFound {
            
            // shift to 15m ago to avoid clock skew errors of a "future" key
            created = Date().shifted(by: -Properties.allowedClockSkew)
            
            try KeychainStorage().set(key: PGPPublicKeyStorage.created.key(tag: self.tag), value: "\(created.timeIntervalSince1970)")
            
            log("Set the PGP public key created date to: \(created)", .warning)
        }
        
        // sign the public key and return it
        return try self.keyPair.exportAsciiArmoredPGPPublicKey(for: userIds, created: created)
    }
    
    var pgpUserIDs:[String] {
        let userIdList = (try? UserIDList(jsonString: KeychainStorage().get(key: PGPPublicKeyStorage.userIDs.key(tag: self.tag)))) ?? UserIDList.empty
        return userIdList.ids
    }

    func updatePGPUserIDPreferences(for identity:String) -> [String] {
        
        var userIdList = (try? UserIDList(jsonString: KeychainStorage().get(key: PGPPublicKeyStorage.userIDs.key(tag: self.tag)))) ?? UserIDList.empty
        
        // add new identity
        userIdList = userIdList.by(updating: identity)

        do {
            try KeychainStorage().set(key: PGPPublicKeyStorage.userIDs.key(tag: self.tag), value: userIdList.jsonString())
            return userIdList.ids
            
        } catch {
            log("could not save pgp identity to keychain: \(error)", .error)
            return userIdList.ids
        }
    }
    
    func getPGPPublicKeyID() throws -> Data {
        
        // get the created time
        guard let pgpPublicKeyCreated = Double(try KeychainStorage().get(key: PGPPublicKeyStorage.created.key(tag: self.tag)))
        else {
            throw KeychainStorageError.notFound
        }
        
        let created = Date(timeIntervalSince1970: pgpPublicKeyCreated)

        let pgpPublicKey = try PGPFormat.PublicKey(create: self.keyPair.publicKey.type.pgpKeyType, publicKeyData: self.keyPair.publicKey.pgpPublicKey(), date: created)

        return try pgpPublicKey.keyID()
    }
}


