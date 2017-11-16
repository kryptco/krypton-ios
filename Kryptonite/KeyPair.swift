//
//  Crypto.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation
import Security
import CommonCrypto


enum KeyIdentifier:String {
    case Public  = "com.kryptco.public"
    case Private = "com.kryptco.private"
    
    func tag(_ tag:String) -> String {
        return "\(self.rawValue).\(tag)"
    }
    
    func tag(_ tag:String, type:KeyType) -> String {
        return "\(self.rawValue).\(type.rawValue).\(tag)"
    }
}

enum KeyType:String {
    case RSA = "rsa"
    case Ed25519 = "ed25519"
    case nistP256 = "ecdsa-sha2-nistp256"
}

enum DigestType {
    case ed25519
    case sha1
    case sha224
    case sha256
    case sha384
    case sha512
}

let KeychainAccessiblity = String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)

protocol PublicKey {
    var type:KeyType {  get }
    func verify(_ message:Data, signature:Data, digestType:DigestType) throws -> Bool
    func export() throws -> Data
    static func importFrom(_ tag:String, publicKeyRaw:Data) throws -> PublicKey
}

protocol PrivateKey {}

protocol KeyPair {
    var publicKey:PublicKey { get }
    var privateKey:PrivateKey { get }
    
    static func loadOrGenerate(_ tag: String) throws -> KeyPair
    static func load(_ tag: String) throws -> KeyPair?
    static func generate(_ tag: String) throws -> KeyPair
    static func destroy(_ tag: String) throws
    
    func sign(data:Data, digestType:DigestType) throws -> Data    
}



