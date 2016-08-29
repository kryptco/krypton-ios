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

class KeyPair {
    
    var publicKey:PublicKey
    var privateKey:SecKey
    
    init(pub:SecKey, priv:SecKey) {
        self.publicKey = PublicKey(key: pub)
        self.privateKey = priv
    }
    
    class func generate(tag: String, keySize: Int, accessGroup:String?) throws -> KeyPair {
    
        let pubTag = tag + ".pub"
        let privTag = tag + ".priv"
    
        var errorRef:Unmanaged<CFErrorRef>?
        let aclOpt = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            SecAccessControlCreateFlags.PrivateKeyUsage, &errorRef)
        
        guard let acl = aclOpt where errorRef == nil else {
            throw CryptoError.ACLCreate
        }
        
        // specify key protection and identity attributes
        var pubKey:SecKey?
        var privKey:SecKey?
        
        let privateAttributes = [
                String(kSecAttrIsPermanent): true,
                String(kSecAttrApplicationTag): privTag,
                String(kSecAttrAccessible): kSecAttrAccessibleAlwaysThisDeviceOnly,
        ]
        
        let publicAttributes = [
                String(kSecAttrIsPermanent): true,
                String(kSecAttrApplicationTag): pubTag,
                String(kSecAttrAccessible): kSecAttrAccessibleAlwaysThisDeviceOnly,
        ]
        
        var keyParams:[String:AnyObject] = [
                String(kSecAttrType): String(kSecAttrKeyTypeEC),
                String(kSecAttrKeySizeInBits): keySize,
                String(kSecAttrTokenID): String(kSecAttrTokenIDSecureEnclave),
        ]
        
        keyParams[String(kSecAttrAccessControl)] = acl
        keyParams[String(kSecAttrAccessible)] = String(kSecAttrAccessibleAlwaysThisDeviceOnly)
        keyParams[String(kSecAttrCanSign)] = true
        keyParams[String(kSecPublicKeyAttrs)] = publicAttributes
        keyParams[String(kSecPrivateKeyAttrs)] = privateAttributes

        let genStatus =  SecKeyGeneratePair(keyParams, &pubKey, &privKey)
        
        guard let pub = pubKey, priv = privKey where genStatus == noErr else {
            throw CryptoError.Generate(genStatus)
        }
        
        return KeyPair(pub: pub, priv: priv)
    }
    
    
    func sign(message:String) throws -> String {


        // convert to data
        let messageData = message.dataUsingEncoding(NSUTF8StringEncoding)
        let blockSize = SecKeyGetBlockSize(privateKey)
        
        guard let
            result = NSMutableData(length: Int(blockSize)),
            data = messageData,
            hash = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))
        else {
            throw CryptoError.Sign(nil)
        }
        
        let hashDataLength = Int(hash.length)
        let hashData = UnsafePointer<UInt8>(hash.bytes)
        
        // Create SHA256 hash of the message
        CC_SHA256(data.bytes, CC_LONG(data.length), UnsafeMutablePointer(hash.mutableBytes))
        
        
        let encryptedData = UnsafeMutablePointer<UInt8>(result.mutableBytes)
        var encryptedDataLength = blockSize
        
        let status = SecKeyRawSign(privateKey, SecPadding.SigRaw, hashData, hashDataLength, encryptedData, &encryptedDataLength)

        guard status == noErr else {
            throw CryptoError.Sign(status)
        }
        
        
        // Create Base64 string of the result
        result.length = encryptedDataLength
        return result.toBase64()
    }
}

struct PublicKey {
    var key:SecKey
    
    
    func verify(message:String, signature:String) throws -> Bool {
        
    }
    func export() throws -> NSData {
        
        let params = [String(kSecReturnData): kCFBooleanTrue,
                      String(kSecClass): kSecClassKey,
                      String(kSecValueRef): key]
        
        var     publicKeyObject:AnyObject?
        let status = SecItemAdd(params, &publicKeyObject)
        
        guard let pubData = publicKeyObject as? NSData where status == noErr else {
            throw CryptoError.Export(status)
        }
        
        return pubData
    }
}



//        var sigBuffer = NSMutableData()
//        sigBuffer.increaseLengthBy(2048)
//        var sigLength = sigBuffer.length
//        let signStatus  = SecKeyRawSign(sk, SecPadding.SigRaw, UnsafePointer<UInt8>(digest.bytes), digest.length, UnsafeMutablePointer<UInt8>(sigBuffer.bytes), &sigLength)
//        printStatus(signStatus)
//        let finalSig = NSData(bytes: sigBuffer.bytes, length: sigLength)
//        print("sig...")
//        print(finalSig.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.EncodingEndLineWithLineFeed))
//        let verifyStatus =  SecKeyRawVerify(pk, SecPadding.SigRaw, UnsafePointer<UInt8>(digest.bytes), digest.length, UnsafeMutablePointer<UInt8>(sigBuffer.bytes), sigLength)
//        printStatus(verifyStatus)


