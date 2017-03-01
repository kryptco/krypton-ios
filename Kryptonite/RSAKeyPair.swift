//
//  RSAKeyPair.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Security
import CommonCrypto


let KeySize = 4096

extension SecKey:PrivateKey {}

class RSAKeyPair:KeyPair {
    
    var rsaPublicKey:RSAPublicKey
    var rsaPrivateKey:SecKey
    
    var publicKey:PublicKey {
        return rsaPublicKey
    }
    var privateKey:PrivateKey {
        return rsaPrivateKey
    }
    
    init(pub:SecKey, priv:SecKey) {
        self.rsaPublicKey = RSAPublicKey(key: pub)
        self.rsaPrivateKey =  priv
    }
    
    class func loadOrGenerate(_ tag: String) throws -> KeyPair {
        do {
            if let kp = try RSAKeyPair.load(tag) {
                return kp
            }
            
            return try RSAKeyPair.generate(tag)
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
                throw CryptoError.load(.RSA, status)
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
                throw CryptoError.load(.RSA, status)
        }
        
        // return the keypair
        
        return RSAKeyPair(pub: pubKey as! SecKey, priv: privKey as! SecKey)
    }
    
    class func generate(_ tag: String) throws -> KeyPair {
        
        guard let keyParams = RSAKeyPair.getPrivateKeyParamsFor(tag: tag, keySize: KeySize) else {
            throw CryptoError.paramCreate
        }
        
        // check if keys for tag already exists
        do {
            if let _ = try RSAKeyPair.load(tag) {
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
            throw CryptoError.generate(.RSA, genStatus)
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
            throw CryptoError.generate(.RSA, status)
        }
        
        // return the key pair
        return RSAKeyPair(pub: pub, priv: priv)
    }
    
    class func destroy(_ tag: String) throws -> Bool {
        
        do {
            let privDelete = try RSAKeyPair.destroyPrivateKey(tag)
            let pubDelete  = try RSAKeyPair.destroyPublicKey(tag)
            
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
                throw CryptoError.destroy(.RSA, status)
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
                throw CryptoError.destroy(.RSA, status)
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
    
    
    func sign(data:Data) throws -> Data {
        return try sign(digest: data.SHA1)
    }
    
    func sign(digest:Data) throws -> Data {
        
        let dataBytes = digest.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: digest.count))
        }
        
        // Create signature
        var sigBufferSize = SecKeyGetBlockSize(self.rsaPrivateKey)
        var result = [UInt8](repeating: 0, count: sigBufferSize)
        
        let status = SecKeyRawSign(rsaPrivateKey, SecPadding.PKCS1SHA1, dataBytes, dataBytes.count, &result, &sigBufferSize)
        
        guard status.isSuccess() else {
            throw CryptoError.sign(.RSA, status)
        }
        
        // Create Base64 string of the result
        
        let resultData = Data(bytes: result[0..<sigBufferSize])
        return resultData
    }
}

struct RSAPublicKey:PublicKey {
    var key:SecKey
    
    var type:KeyType {
        return KeyType.RSA
    }
    
    func verify(_ message:String, signature:String) throws -> Bool {
        
        guard let data = message.data(using: String.Encoding.utf8)
            else {
                throw CryptoError.encoding
        }
        
        let sigData = try signature.fromBase64()
        
        return try verify(data, signature: sigData)
    }
    
    func verify(_ message: Data, signature: Data) throws -> Bool {
        
        let sigBytes = signature.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: signature.count))
        }
        
        // Create SHA1 hash of the message
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1((message as NSData).bytes, CC_LONG(message.count), &hash)
        
        let status = SecKeyRawVerify(key, SecPadding.PKCS1SHA1, hash, hash.count, sigBytes, sigBytes.count)
        
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
        let data = try publicKeyDER.fromBase64()
        return try RSAPublicKey.importFrom(tag, publicKeyRaw: data)
    }
    
    static func importFrom(_ tag:String, publicKeyRaw:Data) throws -> PublicKey {
        
        let pubTag = KeyIdentifier.Public.tag(tag)
        
        var params = [String(kSecClass): kSecClassKey,
                      String(kSecAttrApplicationTag): pubTag,
                      String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
                      String(kSecAttrAccessible): KeychainAccessiblity] as [String : Any]
        
        params[String(kSecAttrKeyClass)] = kSecAttrKeyClassPublic
        params[String(kSecValueData)] = publicKeyRaw
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
        
        return RSAPublicKey(key: pubKey as! SecKey)
    }
}

// Some of the function 'splitIntoComponents' is adapted from
// Heimdal (https://github.com/henrinormak/Heimdall)
// Software Licence (14)

//MARK: Extract Modulus + Exponent

extension RSAPublicKey {
    func splitIntoComponents() throws -> (modulus: Data, exponent: Data) {
        
        let data = try self.export()
        
        // Get the bytes from the keyData
        let pointer = UnsafePointer<CUnsignedChar>(data.bytes)
        let keyBytes = [CUnsignedChar](UnsafeBufferPointer<CUnsignedChar>(start:pointer, count:data.count / MemoryLayout<CUnsignedChar>.size))
        
        // Assumption is that the data is in DER encoding
        // If we can parse it, then return successfully
        var i: NSInteger = 0
        
        // First there should be an ASN.1 SEQUENCE
        if keyBytes[0] != 0x30 {
            throw CryptoError.encoding
        } else {
            i += 1
        }
        
        // Total length of the container
        if let _ = Int(octetBytes: keyBytes, startIdx: &i) {
            // First component is the modulus
            var j = i+1
            if keyBytes[i] == 0x02, let modulusLength = Int(octetBytes: keyBytes, startIdx: &j) {
                let modulus = data.subdata(in: j ..< j+modulusLength)
                j += modulusLength
                
                var k = j+1
                // Second should be the exponent
                if keyBytes[j] == 0x02, let exponentLength = Int(octetBytes: keyBytes, startIdx: &k) {
                    let exponent = data.subdata(in: k ..< k+exponentLength)
                    k += exponentLength
                    
                    return (modulus, exponent)
                }
            }
        }
        
        throw CryptoError.encoding
    }
    
}


