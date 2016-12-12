//
//  KeyManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation


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
            let loadStart = Date().timeIntervalSince1970
            guard let kp = try KeyPair.load(KeyTag.me.rawValue) else {
                throw KeyManagerError.keyDoesNotExist
            }
            let loadEnd = Date().timeIntervalSince1970

            log("keypair load took \(loadEnd - loadStart) seconds")
            
            return KeyManager(kp)
        }
        catch let e {
            log("Crypto Load error -> \(e)", LogType.warning)
            throw e
        }
    }
    
    class func generateKeyPair() throws {
        do {
            let _ = try KeyPair.generate(KeyTag.me.rawValue)
        }
        catch let e {
            log("Crypto Generate error -> \(e)", LogType.warning)
            throw e
        }
    }
    
    class func destroyKeyPair() -> Bool {
        guard let result = try? KeyPair.destroy(KeyTag.me.rawValue) else {
            return false
        }
        
        return result
    }
    
    class func hasKey() -> Bool {
        do {
            let kp = try KeyPair.load(KeyTag.me.rawValue)
            if kp == nil {
                return false
            }
            log("has key is true")
        } catch {
            return false
        }
    
        return true
    }
    
    func getMe() throws -> Peer {
        do {
            let email = try KeychainStorage().get(key: KrMeDataKey)
            let publicKey = try keyPair.publicKey.wireFormat()
            let fp = publicKey.fingerprint()
            
            return Peer(email: email, fingerprint: fp, publicKey: publicKey)
            
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



