//
//  KeyManager.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


enum KeyTag:String {
    case me = "me"
    case peer = "peer"
}

private let KrMeDataKey = "kr_me_data"

enum KeyManagerError:Error {
    case keyDoesNotExist
}
class KeyManager {
    private static var sharedManager:KeyManager?

    var keyPair:KeyPair
    
    init(_ keyPair:KeyPair) {
        self.keyPair = keyPair
    }
    
    class func sharedInstance() throws -> KeyManager {
        if let km = sharedManager {
            return km
        }
        do {
            guard let kp = try KeyPair.load(KeyTag.me.rawValue) else {
                throw KeyManagerError.keyDoesNotExist
            }
            
            sharedManager = KeyManager(kp)
            return sharedManager!
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
        sharedManager = nil
        
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
    
    func getMe() throws -> Peer? {
        do {
            let email = try KeychainStorage().get(key: KrMeDataKey)
            let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
            let fp = try publicKey.fingerprint().toBase64()
            
            return Peer(email: email, fingerprint: fp, publicKey: publicKey)
            
        } catch (let e) {
            throw e
        }
    }
    
    func setMe(email:String) {
        let success = KeychainStorage().set(key: KrMeDataKey, value: email)
        if !success {
            log("failed to store `me` email.", LogType.error)
        }
        
    }
    
}



