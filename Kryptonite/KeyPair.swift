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
}

enum KeyType:String {
    case RSA = "rsa"
    case Ed25519 = "ed25519"
}

let KeychainAccessiblity = String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)

protocol PublicKey {
    func verify(_ message:Data, signature:Data) throws -> Bool
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
    static func destroy(_ tag: String) throws -> Bool
    
    func sign(data:Data) throws -> Data

}

extension KeyPair {
    func signAppendingSSHWirePubkeyToPayload(data:Data) throws -> String {
        var dataClone = Data(data)
        let pubkeyWire = try publicKey.wireFormat()
        dataClone.append(contentsOf: pubkeyWire.bigEndianByteSize())
        dataClone.append(pubkeyWire)
        return try sign(data: dataClone).toBase64()
    }

}


