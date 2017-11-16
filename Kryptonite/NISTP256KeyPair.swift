//
//  NISTP256KeyPair.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Security
import CommonCrypto

class NISTP256KeyPair:KeyPair {
    
    internal static let keySize = 256
    internal class var useSecureEnclave:Bool { return true }
    
    let nistP256PublicKey:NISTP256PublicKey
    let nistP256PrivateKey:SecKey
    
    var publicKey:PublicKey {
        return nistP256PublicKey
    }
    
    var privateKey:PrivateKey {
        return nistP256PrivateKey
    }
    
    private static func access() throws -> SecAccessControl {
        guard let access = SecAccessControlCreateWithFlags(
                                                kCFAllocatorDefault,
                                                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                .privateKeyUsage,
                                                nil)
        else {
            throw CryptoError.badAccess
        }

        return access
    }
    
    private let tag:String
    
    init(publicKey:NISTP256PublicKey, privateKey:SecKey, tag:String) {
        self.nistP256PublicKey = publicKey
        self.nistP256PrivateKey = privateKey
        self.tag = tag
    }
    
    class func loadOrGenerate(_ tag: String) throws -> KeyPair {
        do {
            if let kp = try load(tag) {
                return kp
            }
            
            return try generate(tag)
        } catch (let e) {
            throw e
        }
    }
    
    class func load(_ tag: String) throws -> KeyPair? {
        var attributes:[String: Any] = [
            String(kSecClass): kSecClassKey,
            String(kSecReturnRef): kCFBooleanTrue,
            String(kSecAttrKeyType): kSecAttrKeyTypeECSECPrimeRandom,
            String(kSecAttrApplicationTag): KeyIdentifier.Private.tag(tag),
            String(kSecAttrTokenID): kSecAttrTokenIDSecureEnclave,
            String(kSecAttrAccessControl): try access(),
            ]
        
        if !useSecureEnclave {
            attributes.removeValue(forKey: String(kSecAttrTokenID))
        }

        var privKeyObject:CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &privKeyObject)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status.isSuccess() else {
            throw CryptoError.load(.nistP256, status)
        }
        guard   let privateKeyCF = privKeyObject
        else {
            throw CryptoError.load(.nistP256, nil)
        }
        
        let privateKey:SecKey = privateKeyCF as! SecKey


        // get the public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoError.generate(.nistP256, nil)
        }

        // return the keypair
        return NISTP256KeyPair(publicKey: NISTP256PublicKey(key: publicKey), privateKey: privateKey, tag: tag)
    }
    
    class func generate(_ tag: String) throws -> KeyPair {
        var keyParams:[String: Any] = [
            String(kSecClass): kSecClassKey,
            String(kSecAttrKeyType): kSecAttrKeyTypeECSECPrimeRandom,
            String(kSecAttrKeySizeInBits): keySize,
            String(kSecAttrTokenID): kSecAttrTokenIDSecureEnclave,
            String(kSecPrivateKeyAttrs): [
                String(kSecAttrIsPermanent): true,
                String(kSecAttrApplicationTag): KeyIdentifier.Private.tag(tag),
                String(kSecAttrAccessControl): try access()
            ]
        ]
        
        
        if !useSecureEnclave {
            keyParams.removeValue(forKey: String(kSecAttrTokenID))
        }
        
        // check if keys for tag already exists
        do {
            if let _ = try load(tag) {
                throw CryptoError.tagExists
            }
        } catch (let e) {
            throw e
        }
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            if let err = error?.takeRetainedValue() {
                throw err as Error
            } else {
                throw CryptoError.generate(.nistP256, nil)
            }
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoError.generate(.nistP256, nil)
        }
        
        return NISTP256KeyPair(publicKey: NISTP256PublicKey(key: publicKey), privateKey: privateKey, tag: tag)
    }
    
    class func destroy(_ tag: String) throws {
        var attributes:[String: Any] = [
            String(kSecClass): kSecClassKey,
            String(kSecAttrKeyType): kSecAttrKeyTypeECSECPrimeRandom,
            String(kSecAttrApplicationTag): KeyIdentifier.Private.tag(tag),
            String(kSecAttrTokenID): kSecAttrTokenIDSecureEnclave,
            String(kSecAttrAccessControl): try access(),
        ]
        
        if !useSecureEnclave {
            attributes.removeValue(forKey: String(kSecAttrTokenID))
        }
        
        let status = SecItemDelete(attributes as CFDictionary)
        
        guard status.isSuccess() || status == errSecItemNotFound
            else {
                throw CryptoError.destroy(.nistP256, status)
        }

    }
    
    
    func sign(data:Data, digestType:DigestType) throws -> Data {
        let algorithm = try NISTP256KeyPair.algorithm(for: digestType)
        return try sign(data: data, algorithm: algorithm)
    }
    
    private func sign(data:Data, algorithm:SecKeyAlgorithm) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signatureCFData = SecKeyCreateSignature(nistP256PrivateKey,
                                                          algorithm,
                                                          data as CFData,
                                                          &error)
        else {
            if let err = error?.takeRetainedValue() {
                throw err as Error
            } else {
                throw CryptoError.sign(.nistP256, nil)
            }
        }

        return signatureCFData as Data
    }
    
    /// helper function to map a hash function to the right ECDSA signature algroithm
    static func algorithm(for digestType:DigestType) throws -> SecKeyAlgorithm {
        var algorithm:SecKeyAlgorithm
        
        switch  digestType{
        case .sha1:
            algorithm = .ecdsaSignatureMessageX962SHA1
        case .sha224:
            algorithm = .ecdsaSignatureMessageX962SHA224
        case .sha256:
            algorithm = .ecdsaSignatureMessageX962SHA256
        case .sha384:
            algorithm = .ecdsaSignatureMessageX962SHA384
        case .sha512:
            algorithm = .ecdsaSignatureMessageX962SHA512
        case .ed25519:
            throw CryptoError.unsupportedSignatureDigestAlgorithmType
        }
        
        return algorithm
    }
}

struct NISTP256PublicKey:PublicKey {
    let key:SecKey
    
    var type:KeyType {
        return KeyType.nistP256
    }
    
    func verify(_ message: Data, signature: Data, digestType:DigestType) throws -> Bool {
        let algorithm = try NISTP256KeyPair.algorithm(for: digestType)

        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(key,
                              algorithm,
                              message as CFData,
                              signature as CFData,
                              &error)
        
        guard result else {
            return false
        }
        
        // if result == true but we have an error, handle that
        if let err = error?.takeRetainedValue() {
            throw err as Error
        } else if error != nil {
            throw CryptoError.verify(.nistP256)
        }
        
        // otherwise, result == true, no error
        return true
    }
    
    func export() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) else {
            if let err = error?.takeRetainedValue() {
                throw err as Error
            }
            
            throw CryptoError.export(nil)
        }
        
        return keyData as Data
    }
    
    static func importFrom(_ tag:String, publicKeyRaw:Data) throws -> PublicKey {
        let attributes:[String: Any] = [ String(kSecAttrKeyClass): kSecAttrKeyClassPublic,
                                         String(kSecAttrKeyType): kSecAttrKeyTypeECSECPrimeRandom,
                                         String(kSecAttrKeySizeInBits): NISTP256KeyPair.keySize,
                                         String(kSecAttrApplicationTag): KeyIdentifier.Public.tag(tag)]
        
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(publicKeyRaw as CFData, attributes as CFDictionary, &error) else {
            if let err = error?.takeRetainedValue() {
                throw err as Error
            }
            
            throw CryptoError.publicKeyImport(.nistP256)
        }
        
        return NISTP256PublicKey(key: key)
    }
}

/// Parse a NISTP256X962 Signature
struct NISTP256X962Signature {
    let asn1Encoding:Data
    
    func splitIntoComponents() throws -> (r: Data, s: Data) {
        let bytes = asn1Encoding.bytes
        
        // first byte is the ASN.1 Sequence
        guard bytes.count > 1, bytes[0] == 0x30 else {
            throw CryptoError.encoding
        }
        
        var i = 1
        
        // Total length of the container
        if let _ = Int(octetBytes: bytes, startIdx: &i) {
            // First component is r
            var j = i+1
            if bytes[i] == 0x02, let rLength = Int(octetBytes: bytes, startIdx: &j) {
                let r = asn1Encoding.subdata(in: j ..< j+rLength)
                j += rLength

                var k = j+1
                // Second component is s
                if bytes[j] == 0x02, let sLength = Int(octetBytes: bytes, startIdx: &k) {
                    let s = asn1Encoding.subdata(in: k ..< k+sLength)
                    k += sLength

                    return (r.stripLeadingZeros(), s.stripLeadingZeros())
                }
            }
        }

        throw CryptoError.encoding
    }
}

