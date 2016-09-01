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
            let kp = try KeyPair.loadOrGenerate(KeyTag.me.rawValue)
            sharedManager = KeyManager(kp)
            return sharedManager!
        } catch let e {
            log("Crypto Load or Generate error -> \(e)", LogType.error)
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
    
}
