//
//  Ed25519.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium

private let Ed25519KeychainService = "com.kryptco.keys.ed25519"

class Ed25519KeyPair:KeyPair {

    var edKeyPair:SodiumSignKeyPair
    
    var publicKey:PublicKey {
        return edKeyPair.publicKey
    }
    
    var privateKey: PrivateKey {
        return edKeyPair.secretKey
    }
    
    init(keypair: SodiumSignKeyPair) {
        self.edKeyPair = keypair
    }
    
    static func loadOrGenerate(_ tag: String) throws -> KeyPair {
        do {
            if let kp = try Ed25519KeyPair.load(tag) {
                return kp
            }
            
            return try Ed25519KeyPair.generate(tag)
        } catch (let e) {
            throw e
        }
    }
    
    static func load(_ tag: String) throws -> KeyPair? {
        
        // load the private key
        let privParams:[String : Any] = [String(kSecClass): kSecClassGenericPassword,
                      String(kSecAttrService): Ed25519KeychainService,
                      String(kSecAttrAccount): KeyIdentifier.Private.tag(tag),
                      String(kSecReturnData): kCFBooleanTrue,
                      String(kSecMatchLimit): kSecMatchLimitOne,
                      String(kSecAttrAccessible): KeychainAccessiblity]
        
        var privObject:AnyObject?
        let privStatus = SecItemCopyMatching(privParams as CFDictionary, &privObject)
        
        if privStatus == errSecItemNotFound {
            return nil
        }
        
        guard let privData = privObject as? Data, privStatus.isSuccess() else {
            throw CryptoError.load(.Ed25519, privStatus)
        }
        
        // load the public key
        let pubParams:[String : Any] = [String(kSecClass): kSecClassGenericPassword,
                          String(kSecAttrService): Ed25519KeychainService,
                          String(kSecAttrAccount): KeyIdentifier.Public.tag(tag),
                          String(kSecReturnData): kCFBooleanTrue,
                          String(kSecMatchLimit): kSecMatchLimitOne,
                          String(kSecAttrAccessible): KeychainAccessiblity]
        
        var pubObject:AnyObject?
        let pubStatus = SecItemCopyMatching(pubParams as CFDictionary, &pubObject)
        
        if pubStatus == errSecItemNotFound {
            return nil
        }
        
        guard let pubData = pubObject as? Data, pubStatus.isSuccess() else {
            throw CryptoError.load(.Ed25519, pubStatus)
        }
        
        return Ed25519KeyPair(keypair: Sign.KeyPair(publicKey: pubData, secretKey: privData))
    }
    
    static func generate(_ tag: String) throws -> KeyPair {
        guard let newKeypair = KRSodium.instance().sign.keyPair() else {
            throw CryptoError.generate(.Ed25519, nil)
        }
        
        let priv = newKeypair.secretKey
        let pub = newKeypair.publicKey
        
        // save the private key
        let privParams:[String : Any] = [String(kSecClass): kSecClassGenericPassword,
                          String(kSecAttrService): Ed25519KeychainService,
                          String(kSecAttrAccount): KeyIdentifier.Private.tag(tag),
                          String(kSecValueData): priv,
                          String(kSecAttrAccessible): KeychainAccessiblity]
        
        let privDeleteStatus = SecItemDelete(privParams as CFDictionary)
        guard privDeleteStatus == errSecItemNotFound || privDeleteStatus.isSuccess()
        else {
            log("could not delete item first", .error)
            throw CryptoError.generate(.Ed25519, privDeleteStatus)
        }
        
        let privStatus = SecItemAdd(privParams as CFDictionary, nil)
        guard privStatus.isSuccess() else {
            throw CryptoError.generate(.Ed25519, privStatus)
        }

        // save the public key
        let pubParams:[String : Any] = [String(kSecClass): kSecClassGenericPassword,
                          String(kSecAttrService): Ed25519KeychainService,
                          String(kSecAttrAccount): KeyIdentifier.Public.tag(tag),
                          String(kSecValueData): pub,
                          String(kSecAttrAccessible): KeychainAccessiblity]
        
        let pubDeleteStatus = SecItemDelete(pubParams as CFDictionary)
        guard pubDeleteStatus == errSecItemNotFound || pubDeleteStatus.isSuccess()
            else {
                log("could not delete item first", .error)
                throw CryptoError.generate(.Ed25519, pubDeleteStatus)
        }
        
        let pubStatus = SecItemAdd(pubParams as CFDictionary, nil)
        guard pubStatus.isSuccess() else {
            throw CryptoError.generate(.Ed25519, pubStatus)
        }
        
        
        // return the created keypair
        return Ed25519KeyPair(keypair: newKeypair)
    }
    
    static func destroy(_ tag: String) throws {
        
        // destroy the private key
        let privParams: [String : Any] = [String(kSecClass): kSecClassGenericPassword,
                          String(kSecAttrService): Ed25519KeychainService,
                          String(kSecAttrAccount): KeyIdentifier.Private.tag(tag),
                          String(kSecAttrAccessible):KeychainAccessiblity]
        
        let privDeleteStatus = SecItemDelete(privParams as CFDictionary)
        
        guard privDeleteStatus.isSuccess() || privDeleteStatus == errSecItemNotFound
        else {
            throw CryptoError.destroy(.Ed25519, privDeleteStatus)
        }
        
        // destroy the public key
        let pubParams: [String : Any] = [String(kSecClass): kSecClassGenericPassword,
                          String(kSecAttrService): Ed25519KeychainService,
                          String(kSecAttrAccount): KeyIdentifier.Public.tag(tag),
                          String(kSecAttrAccessible):KeychainAccessiblity]
        
        let pubDeleteStatus = SecItemDelete(pubParams as CFDictionary)
        
        guard pubDeleteStatus.isSuccess() || pubDeleteStatus == errSecItemNotFound
        else {
            throw CryptoError.destroy(.Ed25519, pubDeleteStatus)
        }
    }
    
    func sign(data:Data, digestType:DigestType) throws -> Data {
        guard digestType == .ed25519 else {
            throw CryptoError.unsupportedSignatureDigestAlgorithmType
        }
        guard let sig = KRSodium.instance().sign.signature(message: data, secretKey: self.edKeyPair.secretKey) else {
            throw CryptoError.sign(.Ed25519, nil)
        }
        
        return sig
    }
}

extension Sign.PublicKey:PublicKey {
    var type:KeyType {
        return KeyType.Ed25519
    }
    
    func verify(_ message:Data, signature:Data, digestType:DigestType) throws -> Bool {
        guard digestType == .ed25519 else {
            throw CryptoError.unsupportedSignatureDigestAlgorithmType
        }
        return KRSodium.instance().sign.verify(message: message, publicKey: self, signature: signature)
    }
    func export() throws -> Data {
        return self as Data
    }
    
    static func importFrom(_ tag:String, publicKeyRaw:Data) throws -> PublicKey {
        return publicKeyRaw as Sign.PublicKey
    }
}
extension Sign.SecretKey:PrivateKey {}

