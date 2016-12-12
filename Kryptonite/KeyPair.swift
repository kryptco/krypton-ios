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

let KeychainAccessiblity = String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)

class KeyPair {
    
    var publicKey:PublicKey
    var privateKey:SecKey
    
    init(pub:SecKey, priv:SecKey) {
        self.publicKey = PublicKey(key: pub)
        self.privateKey = priv
    }
    
    init(pub:PublicKey, priv:SecKey) {
        self.publicKey = pub
        self.privateKey = priv
    }
    
    class func loadOrGenerate(_ tag: String) throws -> KeyPair {
        do {
            if let kp = try KeyPair.load(tag) {
                return kp
            }
            
            return try KeyPair.generate(tag)
        } catch (let e) {
            throw e
        }
    }

    class func load(_ tag: String) throws -> KeyPair? {
        // get the private key
        let privTag = KeyIdentifier.Private.tag(tag)

        var params = [String(kSecReturnRef): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                      String(kSecAttrApplicationTag): privTag,
                      String(kSecAttrAccessible):KeychainAccessiblity,
            ] as [String : Any]


        var privKeyObject:AnyObject?
        var status = SecItemCopyMatching(params as CFDictionary, &privKeyObject)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard let privKey = privKeyObject, status.isSuccess()
        else {
            throw CryptoError.load(status)
        }
        
        // get the public key
        let pubTag = KeyIdentifier.Public.tag(tag)
        
        params = [String(kSecReturnRef): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                      String(kSecAttrApplicationTag): pubTag,
                      String(kSecAttrAccessible):KeychainAccessiblity,
                      ] as [String : Any]
        
        var pubKeyObject:AnyObject?
        status = SecItemCopyMatching(params as CFDictionary, &pubKeyObject)
        
        guard let pubKey = pubKeyObject, status.isSuccess()
        else {
            throw CryptoError.load(status)
        }
        
        // return the keypair
        
        return KeyPair(pub: pubKey as! SecKey, priv: privKey as! SecKey)
    }
    
    class func generate(_ tag: String, keySize: Int = 4096) throws -> KeyPair {
    
        guard let keyParams = KeyPair.getPrivateKeyParamsFor(tag: tag, keySize: keySize) else {
            throw CryptoError.paramCreate
        }
        
        // check if keys for tag already exists
        do {
            if let _ = try KeyPair.load(tag) {
                throw CryptoError.tagExists
            }
        } catch (let e) {
            throw e
        }
        
        //otherwise generate
        var pubKey:SecKey?
        var privKey:SecKey?

        let genStatus = SecKeyGeneratePair(keyParams as CFDictionary, &pubKey, &privKey)
        
        guard let pub = pubKey, let priv = privKey , genStatus.isSuccess() else {
            throw CryptoError.generate(genStatus)
        }
        
        // save public key ref
        
        let pubTag = KeyIdentifier.Public.tag(tag)
        var pubParams = [String(kSecReturnRef): kCFBooleanTrue,
                  String(kSecClass): kSecClassKey,
                  String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                  String(kSecAttrApplicationTag): pubTag,
                  String(kSecAttrAccessible):KeychainAccessiblity,
                  ] as [String : Any]
        
        pubParams[String(kSecAttrKeyClass)] = kSecAttrKeyClassPublic
        pubParams[String(kSecValueRef)] = pub
        pubParams[String(kSecAttrIsPermanent)] = kCFBooleanTrue
        pubParams[String(kSecReturnData)] = kCFBooleanTrue


        var ref:AnyObject?
        let status = SecItemAdd(pubParams as CFDictionary, &ref)
        guard status.isSuccess() else {
            throw CryptoError.generate(status)
        }
        
        // return the key pair
        return KeyPair(pub: pub, priv: priv)
    }
    
    class func destroy(_ tag: String) throws -> Bool {
        
        do {
            let privDelete = try KeyPair.destroyPrivateKey(tag)
            let pubDelete  = try KeyPair.destroyPublicKey(tag)

            return privDelete || pubDelete
        } catch (let e) {
            throw e
        }
        
    }
    
    class func destroyPublicKey(_ tag:String) throws -> Bool {
        // delete the public key
        let pubTag = KeyIdentifier.Public.tag(tag)
        
        var params = [String(kSecClass): kSecClassKey,
                      String(kSecAttrApplicationTag): pubTag,
                      String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                      String(kSecAttrAccessible): KeychainAccessiblity] as [String : Any]
        
        params[String(kSecAttrKeyClass)] = kSecAttrKeyClassPublic
        params[String(kSecAttrIsPermanent)] = kCFBooleanTrue
        params[String(kSecReturnRef)] = kCFBooleanTrue


        let status = SecItemDelete(params as CFDictionary)
        if status == errSecItemNotFound {
            return false
        }
        
        guard status.isSuccess()
            else {
                throw CryptoError.destroy(status)
        }
        
        return true
        
    }
    
    
    class func destroyPrivateKey(_ tag:String) throws -> Bool {
        // delete the private key
        let privTag = KeyIdentifier.Private.tag(tag)
        
        let params = [String(kSecReturnRef): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                      String(kSecAttrApplicationTag): privTag,
                      String(kSecAttrAccessible):KeychainAccessiblity,
                      ] as [String : Any]
        
        
        let status = SecItemDelete(params as CFDictionary)
        if status == errSecItemNotFound {
            return false
        }
        
        guard status.isSuccess()
        else {
            throw CryptoError.destroy(status)
        }
        
        
        return true
    }
    
    private class func getPrivateKeyParamsFor(tag:String, keySize:Int) -> [String:Any]? {
        let privTag = KeyIdentifier.Private.tag(tag)
        
        let privateAttributes:[String:Any] = [
            String(kSecAttrIsPermanent): kCFBooleanTrue,
            String(kSecAttrApplicationTag): privTag,
            String(kSecAttrAccessible): KeychainAccessiblity,
            ]
        
        var keyParams:[String:Any] = [
            String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
            String(kSecAttrKeySizeInBits): keySize,
            ]
        
        keyParams[String(kSecAttrAccessible)] = KeychainAccessiblity
        keyParams[String(kSecPrivateKeyAttrs)] = privateAttributes

        return keyParams
    }
    
    
    func sign(data:Data) throws -> String {
        // Create SHA256 hash of the message
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256((data as NSData).bytes, CC_LONG(data.count), &hash)
        
        return try sign(digest: Data(bytes: hash))
    }
    
    func sign(digest:Data) throws -> String {
        
        let dataBytes = digest.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: digest.count))
        }
        
        // Create signature
        var sigBufferSize = SecKeyGetBlockSize(privateKey)
        var result = [UInt8](repeating: 0, count: sigBufferSize)
        
        let status = SecKeyRawSign(privateKey, SecPadding.PKCS1, dataBytes, dataBytes.count, &result, &sigBufferSize)
        
        guard status.isSuccess() else {
            throw CryptoError.sign(status)
        }
        
        // Create Base64 string of the result
        
        let resultData = Data(bytes: result[0..<sigBufferSize])
        return resultData.toBase64()
    }
}

struct PublicKey {
    var key:SecKey
    
    
    func verify(_ message:String, signature:String) throws -> Bool {
        
        guard let data = message.data(using: String.Encoding.utf8)
        else {
            throw CryptoError.encoding
        }
        
        let sigData = try signature.fromBase64()
        
        let sigBytes = sigData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: sigData.count))
        }
        
        // Create SHA256 hash of the message
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256((data as NSData).bytes, CC_LONG(data.count), &hash)

        let status = SecKeyRawVerify(key, SecPadding.PKCS1, hash, hash.count, sigBytes, sigBytes.count)
        
        guard status.isSuccess() else {
            return false
        }
        
        return true

    }
    
    func export() throws -> Data {
        
        var params = [String(kSecReturnData): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecValueRef): key] as [String : Any]
        
        var publicKeyObject:AnyObject?
        var status = SecItemCopyMatching(params as CFDictionary, &publicKeyObject)
        
        
        if status == errSecItemNotFound {
            params[String(kSecAttrAccessible)] = KeychainAccessiblity
            status = SecItemAdd(params as CFDictionary, &publicKeyObject)
        }

        guard let pubData = (publicKeyObject as? Data), status.isSuccess()
        else {
            throw CryptoError.export(status)
        }
        
        return pubData
    }
    
    static func importFrom(_ tag:String, publicKeyDER:String) throws -> PublicKey {
        
        let pubTag = KeyIdentifier.Public.tag(tag)
        let data = try publicKeyDER.fromBase64()

        var params = [String(kSecClass): kSecClassKey,
                      String(kSecAttrApplicationTag): pubTag,
                      String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                      String(kSecAttrAccessible): KeychainAccessiblity] as [String : Any]
        
        params[String(kSecAttrKeyClass)] = kSecAttrKeyClassPublic
        params[String(kSecValueData)] = data
        params[String(kSecAttrIsPermanent)] = kCFBooleanTrue
        params[String(kSecReturnRef)] = kCFBooleanTrue
        
        var publicKeyObject:AnyObject?
        var status = SecItemAdd(params as CFDictionary, &publicKeyObject)
        
        guard status.isSuccess() || status == errSecDuplicateItem
        else {
            throw CryptoError.export(status)
        }
        
        status = SecItemCopyMatching(params as CFDictionary, &publicKeyObject)
        
        guard let pubKey = publicKeyObject, status.isSuccess()
        else {
            throw CryptoError.export(status)
        }
            
        return PublicKey(key: pubKey as! SecKey)
    }
    
}


