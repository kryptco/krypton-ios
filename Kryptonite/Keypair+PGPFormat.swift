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

private let KryptonitePGPComment = "Made with Kryptonite (v\(Properties.currentVersion.string))"

extension KeyType {
    var pgpKeyType:PGPFormat.PublicKeyAlgorithm {
        switch self {
        case .Ed25519:
            return PGPFormat.PublicKeyAlgorithm.ecc
        case .RSA:
            return PGPFormat.PublicKeyAlgorithm.rsaSignOnly
        }
    }

    func digestType(for hashAlgorithm:Signature.HashAlgorithm) -> DigestType {
        switch self {
        case .Ed25519:
            return DigestType.ed25519
        case .RSA:
            switch hashAlgorithm {
            case .sha1:
                return DigestType.sha1
            case .sha224:
                return DigestType.sha224
            case .sha256:
                return DigestType.sha256
            case .sha384:
                return DigestType.sha384
            case .sha512:
                return DigestType.sha512
            }
        }
    }
}


// MARK: PGPPublicKeyConvertible
protocol PGPPublicKeyConvertible {
    func pgpPublicKeyData() throws -> PGPFormat.PublicKeyData
}

struct UnknownPGPKeyFormat:Error {}

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
        let modulusFixed = Data(bytes: modulus.bytes[1 ..< modulus.count])
        
        return PGPFormat.RSAPublicKey(modulus: modulusFixed, exponent: exponent)
    }
}

extension Sign.PublicKey:PGPPublicKeyConvertible {
    func pgpPublicKeyData() throws -> PGPFormat.PublicKeyData {
        return PGPFormat.ECCPublicKey(rawData: self)
    }
}

// Keypair extension to create self-signed PGP keys
extension KeyPair {
    
    private func createPGPPublicKeyPackets(for identity:String, hashAlgorithm:PGPFormat.Signature.HashAlgorithm = .sha512) throws -> [Packet] {
        
        // create the public key
        let pgpPublicKey = try PGPFormat.PublicKey(create: self.publicKey.type.pgpKeyType, publicKeyData: self.publicKey.pgpPublicKey())
        
        let userID = PGPFormat.UserID(content: identity)
        let pubKeyToSign = PGPFormat.PublicKeyIdentityToSign(publicKey: pgpPublicKey, userID: userID)
        
        // ready the data to hash
        let subpackets:[SignatureSubpacketable] = [SignatureCreated(date: pgpPublicKey.created), PGPFormat.SignatureKeyFlags(flagTypes: [PGPFormat.KeyFlagType.signData])]
        
        let dataToHash = try pubKeyToSign.dataToHash(hashAlgorithm: hashAlgorithm, hashedSubpacketables: subpackets)
        
        // hash it
        var hash:Data
        switch hashAlgorithm {
        case .sha1:
            hash = dataToHash.SHA1
        case .sha224:
            hash = dataToHash.SHA224
        case .sha256:
            hash = dataToHash.SHA256
        case .sha384:
            hash = dataToHash.SHA384
        case .sha512:
            hash = dataToHash.SHA512
        }
        
        // sign it
        var signedHash:Data
        switch self.publicKey.type {
        case .Ed25519: // sign the hash for ed25519
            signedHash = try self.sign(data: hash, digestType: self.publicKey.type.digestType(for: hashAlgorithm))
        case .RSA: // sign the pre hashed data (data will be hashed before signed)
            signedHash = try self.sign(data: dataToHash, digestType: self.publicKey.type.digestType(for: hashAlgorithm))
        }

        // compile the signed public key packets
        let signedPublicKey = try pubKeyToSign.signedPublicKey(hash: hash, hashAlgorithm: PGPFormat.Signature.HashAlgorithm.sha512, hashedSubpacketables: subpackets, signatureData: signedHash)
        
        return try signedPublicKey.toPackets()
    }
    
    func createAsciiArmoredPGPPublicKey(for identity:String) throws -> AsciiArmorMessage {
        let packets = try createPGPPublicKeyPackets(for: identity)
        
        return try AsciiArmorMessage(packets: packets, blockType: ArmorMessageBlock.publicKey, comment: KryptonitePGPComment)
    }

}
