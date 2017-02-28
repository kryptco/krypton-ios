//
//  Ed25519.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium


class Ed25519KeyPair:KeyPair {

    var edPublicKey:Sign.PublicKey
    var edPrivateKey:Sign.SecretKey
    
    var publicKey:PublicKey {
        return edPublicKey
    }
    
    var privateKey: PrivateKey {
        return edPrivateKey
    }
    
    init(sodiumKeyPair: Sign.KeyPair) {
        self.edPublicKey = sodiumKeyPair.publicKey
        self.edPrivateKey = sodiumKeyPair.secretKey
    }
    
    static func loadOrGenerate(_ tag: String) throws -> KeyPair {
        
        
    }
    static func load(_ tag: String) throws -> KeyPair? {
        
    }
    static func generate(_ tag: String) throws -> KeyPair {
        guard let newKeypair = try KRSodium.shared().sign.keyPair() else {
            throw CryptoError.generate(.Ed25519, -1)
        }
        
        return Ed25519KeyPair(sodiumKeyPair: newKeypair)
    }
    static func destroy(_ tag: String) throws -> Bool {
        
    }
    
    func sign(data:Data) throws -> String {
        
    }
}

extension Sign.PublicKey:PublicKey {
    func verify(_ message:Data, signature:Data) throws -> Bool {
        
    }
    func export() throws -> Data {
        
    }
    static func importFrom(_ tag:String, publicKeyRaw:Data) throws -> PublicKey {
        
    }
}
extension Sign.SecretKey:PrivateKey {}
