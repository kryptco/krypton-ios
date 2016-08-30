//
//  Crypto.swift
//  krSSH
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
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
    
    class func loadOrGenerate(_ tag: String) throws -> KeyPair? {
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
    
 //       guard let acl = KeyPair.getACL() else {
 //           throw CryptoError.paramCreate
 //       }
        
        // get the private key
        let privTag = KeyIdentifier.Private.tag(tag)

        var params = [String(kSecReturnRef): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecAttrType): kSecAttrKeyTypeEC,
                      String(kSecAttrApplicationTag): privTag,
                      String(kSecAttrAccessible):String(kSecAttrAccessibleAlwaysThisDeviceOnly),
            ] as [String : Any]


        if TARGET_IPHONE_SIMULATOR == 0 {
            print(" -- using secure enclave for key gen --")
            
            params[String(kSecAttrTokenID)] = String(kSecAttrTokenIDSecureEnclave)
            //params[String(kSecAttrAccessControl)] = acl
        }

        params[String(kSecAttrCanSign)] = kCFBooleanTrue

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
                      String(kSecAttrType): kSecAttrKeyTypeEC,
                      String(kSecAttrApplicationTag): pubTag,
                      String(kSecAttrAccessible):String(kSecAttrAccessibleAlwaysThisDeviceOnly),
                      ] as [String : Any]
        
        params[String(kSecAttrCanVerify)] = kCFBooleanTrue
        
        var pubKeyObject:AnyObject?
        status = SecItemCopyMatching(params as CFDictionary, &pubKeyObject)
        
        guard let pubKey = pubKeyObject, status.isSuccess()
        else {
            throw CryptoError.load(status)
        }
        
        // return the keypair
        
        return KeyPair(pub: pubKey as! SecKey, priv: privKey as! SecKey)
    }
    
    class func generate(_ tag: String, keySize: Int = 256) throws -> KeyPair {
    
        guard let keyParams = KeyPair.getParamsFor(tag: tag, keySize: keySize) else {
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
        
        return KeyPair(pub: pub, priv: priv)
    }
    
    class func destroy(_ tag: String) throws -> Bool {
        
        // delete the private key
        let privTag = KeyIdentifier.Private.tag(tag)
        
        var params = [String(kSecReturnRef): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecAttrType): kSecAttrKeyTypeEC,
                      String(kSecAttrApplicationTag): privTag,
                      String(kSecAttrAccessible):String(kSecAttrAccessibleAlwaysThisDeviceOnly),
                      ] as [String : Any]
        
        
        if TARGET_IPHONE_SIMULATOR == 0 {
            print(" -- using secure enclave for key gen --")
            
            params[String(kSecAttrTokenID)] = String(kSecAttrTokenIDSecureEnclave)
        }
        
        params[String(kSecAttrCanSign)] = kCFBooleanTrue
        
        var status = SecItemDelete(params as CFDictionary)
        
        if status == errSecItemNotFound {
            return false
        }
        
        guard status.isSuccess()
        else {
            throw CryptoError.destroy(status)
        }
        
        // delete the public key
        let pubTag = KeyIdentifier.Public.tag(tag)
        
        params = [String(kSecReturnRef): kCFBooleanTrue,
                  String(kSecClass): kSecClassKey,
                  String(kSecAttrType): kSecAttrKeyTypeEC,
                  String(kSecAttrApplicationTag): pubTag,
                  String(kSecAttrAccessible):String(kSecAttrAccessibleAlwaysThisDeviceOnly),
                  ] as [String : Any]
        
        params[String(kSecAttrCanVerify)] = kCFBooleanTrue
        
        status = SecItemDelete(params as CFDictionary)
        
        guard status.isSuccess()
        else {
            throw CryptoError.destroy(status)
        }
        
        // return the keypair
        
        return true
    }
    
    private class func getACL() -> SecAccessControl? {
        var errorRef:Unmanaged<CFError>?
        let aclOpt = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            SecAccessControlCreateFlags.privateKeyUsage, &errorRef)
        
        return aclOpt
    }
    
    private class func getParamsFor(tag:String, keySize:Int = 256) -> [String:Any]? {
        let privTag = KeyIdentifier.Private.tag(tag)
        let pubTag  = KeyIdentifier.Public.tag(tag)
        
        guard let acl = KeyPair.getACL() else {
            return nil
        }
        
        let privateAttributes:[String:Any] = [
            String(kSecAttrIsPermanent): kCFBooleanTrue,
            String(kSecAttrApplicationTag): privTag,
            String(kSecAttrAccessible): kSecAttrAccessibleAlwaysThisDeviceOnly,
            ]
        
        let publicAttributes:[String:Any] = [
            String(kSecAttrIsPermanent): kCFBooleanTrue,
            String(kSecAttrApplicationTag): pubTag,
            String(kSecAttrAccessible): kSecAttrAccessibleAlwaysThisDeviceOnly,
            ]
        
        var keyParams:[String:Any] = [
            String(kSecAttrType): kSecAttrKeyTypeEC,
            String(kSecAttrKeySizeInBits): keySize,
            ]
        
        if TARGET_IPHONE_SIMULATOR == 0 {
            print("warning: using secure enclave for private key.")
            
            keyParams[String(kSecAttrTokenID)] = String(kSecAttrTokenIDSecureEnclave)
            keyParams[String(kSecAttrAccessControl)] = acl
        }
        
        keyParams[String(kSecAttrAccessible)] = String(kSecAttrAccessibleAlwaysThisDeviceOnly)
        keyParams[String(kSecAttrCanSign)] = kCFBooleanTrue
        keyParams[String(kSecAttrCanVerify)] = kCFBooleanTrue
        
        keyParams[String(kSecPrivateKeyAttrs)] = privateAttributes
        keyParams[String(kSecPublicKeyAttrs)] = publicAttributes

        return keyParams
    }
    
    
    func sign(_ message:String) throws -> String {
        // convert to data
        let messageData = message.data(using: String.Encoding.utf8)
        
        guard let data = messageData
        else {
            throw CryptoError.encoding
        }
    
        // Create SHA256 hash of the message
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256((data as NSData).bytes, CC_LONG(data.count), &hash)
        
        
        // Create signature
        var sigBufferSize = 2048
        var result = [UInt8](repeating: 0, count: sigBufferSize)
        
        let status = SecKeyRawSign(privateKey, SecPadding.PKCS1, hash, hash.count, &result, &sigBufferSize)

        guard status == noErr else {
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
        
        guard let
            data = message.data(using: String.Encoding.utf8),
            let sigData = signature.fromBase64()
        else {
            throw CryptoError.encoding
        }
        
        let sigBytes = sigData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: sigData.count))
        }
        
        // Create SHA256 hash of the message
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256((data as NSData).bytes, CC_LONG(data.count), &hash)

        let status = SecKeyRawVerify(key, SecPadding.PKCS1, hash, hash.count, sigBytes, sigBytes.count)
        
        guard status == noErr else {
            return false
        }
        
        return true

    }
    
    func export() throws -> Data {
        
        let params = [String(kSecReturnData): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecValueRef): key] as [String : Any]
        
        var publicKeyObject:AnyObject?
        var status = SecItemAdd(params as CFDictionary, &publicKeyObject)
        
        if status == errSecDuplicateItem {
             status = SecItemCopyMatching(params as CFDictionary, &publicKeyObject)
        }

        guard let pubData = (publicKeyObject as? Data), status.isSuccess()
        else {
            throw CryptoError.export(status)
        }
        
        return pubData
    }
    
    static func importFrom(_ tag:String, publicKeyDER:String) throws -> PublicKey {
        
        let pubTag = KeyIdentifier.Public.tag(tag)

        guard let data = publicKeyDER.fromBase64()
        else {
            throw CryptoError.encoding
        }

        let params = [String(kSecClass): kSecClassKey,
                      String(kSecValueData): data,
                      String(kSecAttrApplicationTag): pubTag,
                      String(kSecReturnRef): kCFBooleanTrue,
                      String(kSecAttrKeyType): kSecAttrKeyTypeEC,
                      String(kSecAttrAccessible): kSecAttrAccessibleAlwaysThisDeviceOnly] as [String : Any]
        
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


