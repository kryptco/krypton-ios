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
    case peer = "peer"
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
    
    class func destroyKeyPair() -> Bool {
        let rsaResult = (try? RSAKeyPair.destroy(KeyTag.me.rawValue)) ?? false
        let edResult = (try? Ed25519KeyPair.destroy(KeyTag.me.rawValue)) ?? false
        let pgpResult = KeychainStorage().delete(key: KeyTag.me.publicPGPStorageKey)
        
        return (rsaResult || edResult) && pgpResult
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
        do {
            return try KeychainStorage().get(key: KrMeDataKey)
        } catch (let e) {
            throw e
        }
    }
    
    class func setMe(email:String) {
        let success = KeychainStorage().set(key: KrMeDataKey, value: email)
        if !success {
            log("failed to store `me` email.", LogType.error)
        }
        dispatchAsync { Analytics.sendEmailToTeamsIfNeeded(email: email) }
    }
    
    class func clearMe() {
        let success = KeychainStorage().delete(key: KrMeDataKey)
        if !success {
            log("failed to delete `me` email.", LogType.error)
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
struct GetPGPPublicKeyIDError:Error{}
extension KeyManager {
    func loadPGPPublicKey() throws -> AsciiArmorMessage {
        do { // try to load saved pgp public key
            let pgpPublicKeyData = try KeychainStorage().getData(key: KeyTag.me.publicPGPStorageKey)
            let packets = try [Packet](data: pgpPublicKeyData)
            return try AsciiArmorMessage(packets: packets, blockType: ArmorMessageBlock.publicKey)
        
        } catch KeychainStorageError.notFound { // doesn't exist so create it
            let me = try self.getMe()
            let pgpPublicKey = try self.keyPair.exportAsciiArmoredPGPPublicKey(for: " <\(me)>")
            let _ = KeychainStorage().setData(key: KeyTag.me.publicPGPStorageKey, data: pgpPublicKey.packetData)
            
            return pgpPublicKey
        } catch {
            throw error
        }
    }
    
    func getPGPPublicKeyID() throws -> Data {
        let pgpPublicKeyData = try self.loadPGPPublicKey().packetData
        let packets = try [Packetable](data: pgpPublicKeyData)
        
        guard let publicKey = packets.filter({ $0 is PGPFormat.PublicKey}).first as? PGPFormat.PublicKey
        else {
            throw GetPGPPublicKeyIDError()
        }
        
        return try publicKey.keyID()
    }
}


