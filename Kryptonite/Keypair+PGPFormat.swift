//
//  Keypair+PGPFormat.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium
import CommonCrypto
import PGPFormat

extension KeyType {
    var pgpKeyType:PGPFormat.PublicKeyAlgorithm {
        switch self {
        case .Ed25519:
            return PGPFormat.PublicKeyAlgorithm.ed25519
        case .nistP256:
            return PGPFormat.PublicKeyAlgorithm.ecdsa
        case .RSA:
            return PGPFormat.PublicKeyAlgorithm.rsaSignOnly
        }
    }
}

extension DigestType {
    init(from hashAlgorithm:Signature.HashAlgorithm) {
        switch hashAlgorithm {
        case .sha1:
            self = .sha1
        case .sha224:
            self = .sha224
        case .sha256:
            self = .sha256
        case .sha384:
            self = .sha384
        case .sha512:
            self = .sha512
        }
    }
}


// MARK: PGPPublicKeyConvertible
protocol PGPPublicKeyConvertible {
    func pgpPublicKeyData() throws -> PGPFormat.PublicKeyData
}

struct UnknownPGPKeyFormat:Error {}
struct ModulusTooShort:Error {}

extension PublicKey {
    func pgpPublicKey() throws -> PGPFormat.PublicKeyData {
        guard let pgpKey = self as? PGPPublicKeyConvertible
            else {
                throw UnknownPGPKeyFormat()
        }
        
        return try pgpKey.pgpPublicKeyData()
    }
}

extension RSAPublicKey:PGPPublicKeyConvertible {
    func pgpPublicKeyData() throws -> PGPFormat.PublicKeyData {
        let (modulus, exponent) = try self.splitIntoComponents()
        guard modulus.count >= 1 else {
            throw ModulusTooShort()
        }
        
        let modulusFixed = Data(bytes: modulus.bytes[1 ..< modulus.count])
        
        return PGPFormat.RSAPublicKey(modulus: modulusFixed, exponent: exponent)
    }
}

extension Sign.PublicKey:PGPPublicKeyConvertible {
    func pgpPublicKeyData() throws -> PGPFormat.PublicKeyData {
        return PGPFormat.ECPublicKey(curve: .ed25519, rawData: self)
    }
}

extension NISTP256PublicKey:PGPPublicKeyConvertible {
    func pgpPublicKeyData() throws -> PGPFormat.PublicKeyData {
        return try PGPFormat.ECPublicKey(curve: .nistP256, prefixedRawData: self.export())
    }
}

/** 
    Extend Keypair Signatures to hash and return hash + signed hash
 */

extension KeyPair {
    
    /** 
        Return the hash and the signed hash
        Note: Ed25519 signs the hash itself as per OpenPGP RFC for Ed25519.
     */
    func sign(data:Data, using hashAlgorithm:Signature.HashAlgorithm) throws -> (hash:Data, signedHash:[Data]) {
        var hash:Data
        var signedHash:[Data]
        
        switch hashAlgorithm {
        case .sha1:
            hash = data.SHA1
        case .sha224:
            hash = data.SHA224
        case .sha256:
            hash = data.SHA256
        case .sha384:
            hash = data.SHA384
        case .sha512:
            hash = data.SHA512
        }
        
        let digestType = DigestType(from: hashAlgorithm)
        
        switch self.publicKey.type {
        case .Ed25519: // sign the hash for Ed25519
            let signature = try self.sign(data: hash, digestType: .ed25519)
            
            guard signature.count == KRSodium.instance().sign.Bytes
            else {
                throw CryptoError.sign(.Ed25519, nil)
            }
            
            let r = signature[0 ..< signature.count/2]
            let s = signature[signature.count/2 ..< signature.count]
            
            signedHash = [r,s]
            
        case .nistP256: // sign the hash for nistp256 and format signature from asn1:
            let signature = try self.sign(data: data, digestType: digestType)
            let asn1Signature = NISTP256X962Signature(asn1Encoding: signature)
            let (r,s) = try asn1Signature.splitIntoComponents()
            
            signedHash = [r,s]
            
        case .RSA: // sign the pre hashed data (data will be hashed before signed)
            signedHash = [try self.sign(data: data, digestType: digestType)]
        }
        
        return (hash, signedHash)
    }
}

/** 
    Extend Keypair to export self-signed PGP keys and create PGP Signatures
*/
extension KeyPair {
    
    /** 
        Create PGP Signed Public Key: (PublicKey, UserID, Signature Packets)
    */
    private func createPGPPublicKeyMessage(for identities:[String], created:Date, hashAlgorithm:PGPFormat.Signature.HashAlgorithm = .sha512) throws -> PGPFormat.Message {
        
        // create the public key
        let pgpPublicKey = try PGPFormat.PublicKey(create: self.publicKey.type.pgpKeyType, publicKeyData: self.publicKey.pgpPublicKey(), date: created)
        let subpackets:[SignatureSubpacketable] = [
            PGPFormat.SignatureCreated(date: Date()),
            PGPFormat.SignatureKeyFlags(flagTypes: [PGPFormat.SignatureKeyFlags.FlagType.signData])]

        // signature for each userid
        var signedPublicKeys:[PGPFormat.SignedPublicKeyIdentity] = []
        try identities.forEach {
            let userID = PGPFormat.UserID(content: $0)

            var signedPublicKey = try PGPFormat.SignedPublicKeyIdentity(publicKey: pgpPublicKey, userID: userID, hashAlgorithm: hashAlgorithm, hashedSubpacketables: subpackets)
            
            // ready the data to hash
            let dataToHash = try signedPublicKey.dataToHash()
            
            // sign it and get hash back
            let (hash, signedHash) = try self.sign(data: dataToHash, using: hashAlgorithm)
            
            // compile the signed public key packets
            try signedPublicKey.set(hash: hash, signedHash: signedHash)

            // join the signed public keys
            signedPublicKeys.append(signedPublicKey)
        }
        
        return try SignedPublicKeyIdentities(signedPublicKeys).toMessage()
    }
    
    /**
        Export a public key as a PGP Public Key by
        creating a self-signed PGP PublicKey for multiple identities
     */
    func exportAsciiArmoredPGPPublicKey(for identities:[String], created:Date = Date(), hashAlgorithm:PGPFormat.Signature.HashAlgorithm = .sha512) throws -> AsciiArmorMessage {
        return try createPGPPublicKeyMessage(for: identities, created: created, hashAlgorithm: hashAlgorithm).armoredMessage(blockType: .publicKey, comment: Properties.pgpMessageComment)
    }
    
    /**
        Export a public key as a PGP Public Key by
        creating a self-signed PGP PublicKey
    */
    func exportAsciiArmoredPGPPublicKey(for identity:String, created:Date = Date(), hashAlgorithm:PGPFormat.Signature.HashAlgorithm = .sha512) throws -> AsciiArmorMessage {
        return try self.exportAsciiArmoredPGPPublicKey(for: [identity], created: created, hashAlgorithm: hashAlgorithm)
    }
    
    /**
        Create a PGP signature over a binary document
    */
    func createAsciiArmoredBinaryDocumentSignature(for binaryData:Data, using hashAlgorithm:PGPFormat.Signature.HashAlgorithm = .sha512, keyID:Data) throws -> AsciiArmorMessage {
        
        let subpackets:[SignatureSubpacketable] = [
            PGPFormat.SignatureCreated(date: Date())]

        var signedBinary = SignedBinaryDocument(binary: binaryData, publicKeyAlgorithm: self.publicKey.type.pgpKeyType, hashAlgorithm: hashAlgorithm, hashedSubpacketables: subpackets)
        
        signedBinary.signature.unhashedSubpacketables = [SignatureIssuer(keyID: keyID)]

        // ready the data to hash
        let dataToHash = try signedBinary.dataToHash()
        
        // sign it and get hash back
        let (hash, signedHash) = try self.sign(data: dataToHash, using: hashAlgorithm)
        
        // compile the signed public key packets
        try signedBinary.set(hash: hash, signedHash: signedHash)

        // return ascii armored signature
        return try signedBinary.toMessage().armoredMessage(blockType: .signature, comment: Properties.pgpMessageComment)
    }
    
    /**
        Create an "attached" PGP signature over a binary document
     */
    func createAsciiArmoredAttachedBinaryDocumentSignature(for binaryData:Data, using hashAlgorithm:PGPFormat.Signature.HashAlgorithm = .sha512, keyID:Data) throws -> AsciiArmorMessage {
        
        let subpackets:[SignatureSubpacketable] = [
            PGPFormat.SignatureCreated(date: Date())]
        
        var signedBinary = SignedAttachedBinaryDocument(binaryData: binaryData, keyID: keyID, publicKeyAlgorithm: self.publicKey.type.pgpKeyType, hashAlgorithm: hashAlgorithm, hashedSubpacketables: subpackets)
        
        signedBinary.signature.unhashedSubpacketables = [SignatureIssuer(keyID: keyID)]
        
        // ready the data to hash
        let dataToHash = try signedBinary.dataToHash()
        
        // sign it and get hash back
        let (hash, signedHash) = try self.sign(data: dataToHash, using: hashAlgorithm)
        
        // compile the signed public key packets
        try signedBinary.set(hash: hash, signedHash: signedHash)
        
        // return ascii armored signature
        return try signedBinary.toMessage().armoredMessage(blockType: .signature, comment: Properties.pgpMessageComment)
    }
    
    
    /**
        Create a PGP Signature over a Git Commit
     */
    func signGitCommit(with commitInfo:CommitInfo, keyID:Data) throws -> AsciiArmorMessage {
        return try self.createAsciiArmoredBinaryDocumentSignature(for: commitInfo.data, keyID: keyID)
    }
    
    /**
        Create a PGP Signature over a Git Tag
     */
    func signGitTag(with tagInfo:TagInfo, keyID:Data) throws -> AsciiArmorMessage {
        return try self.createAsciiArmoredBinaryDocumentSignature(for: tagInfo.data, keyID: keyID)
    }
}
