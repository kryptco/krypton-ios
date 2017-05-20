//
//  CodeSigningTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/19/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

import XCTest
import PGPFormat
import Sodium

class CodeSigningTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testCreatePGPPublicKeyRSA() {
        do {
            let _ = try RSAKeyPair.destroy("test")
            let keypair = try RSAKeyPair.generate("test")
            let publicKey = keypair.publicKey as! RSAPublicKey
            let (modulus, exponent) = try publicKey.splitIntoComponents()
            
            let modulusFixed = Data(bytes: modulus.bytes[1 ..< modulus.count])

            let pgpPublicKey = PGPFormat.PublicKey(create: PublicKeyAlgorithm.rsaSignOnly, publicKeyData: PGPFormat.RSAPublicKey(modulus: modulusFixed, exponent: exponent))
            let userID = PGPFormat.UserID(name: "alex grinman", email: "me@alexgr.in")
            let pubKeyToSign = PGPFormat.PublicKeyIdentityToSign(publicKey: pgpPublicKey, userID: userID)
            
            let subpackets:[SignatureSubpacketable] = [SignatureCreated(date: pgpPublicKey.created), PGPFormat.SignatureKeyFlags(flagTypes: [PGPFormat.KeyFlagType.signData])]
            
            let dataToHash = try pubKeyToSign.dataToHash(hashAlgorithm: PGPFormat.Signature.HashAlgorithm.sha512, hashedSubpacketables: subpackets)
            let hash = dataToHash.SHA512
            
            let signedHashBytes = try keypair.sign(data: dataToHash, digestType: DigestType.sha512).bytes
            let signedHash = Data(bytes: signedHashBytes)
            
            let signedPublicKey = try pubKeyToSign.signedPublicKey(hash: hash, hashAlgorithm: PGPFormat.Signature.HashAlgorithm.sha512, hashedSubpacketables: subpackets, signatureData: signedHash)
            
            let outMsg = try PGPFormat.AsciiArmorMessage(packets: signedPublicKey.toPackets(), blockType: PGPFormat.ArmorMessageBlock.publicKey).toString()
            print(outMsg)
            
            let packets = try [Packet](data: PGPFormat.AsciiArmorMessage(string: outMsg).packetData)
            let _ = try PGPFormat.PublicKey(packet: packets[0])
            let _ = try PGPFormat.UserID(packet: packets[1])
            let _ = try PGPFormat.Signature(packet: packets[2])

        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testCreatePGPPublicKeyEd25519() {
        do {
            let _ = try Ed25519KeyPair.destroy("test")
            let keypair = try Ed25519KeyPair.generate("test")
            let publicKey = keypair.publicKey as! Sign.PublicKey
            
            let pubKeyBytes = publicKey.bytes
            
            let pgpPublicKey = PGPFormat.PublicKey(create: PublicKeyAlgorithm.ecc, publicKeyData: PGPFormat.ECCPublicKey(rawData: publicKey))
            let userID = PGPFormat.UserID(name: "alex grinman", email: "me@alexgr.in")
            let pubKeyToSign = PGPFormat.PublicKeyIdentityToSign(publicKey: pgpPublicKey, userID: userID)
            
            
//            let fingerprintBytes = try pgpPublicKey.fingerprint().bytes
//            let unknownSubpacketable = SignatureIssuerFingerprint(fingerprint: Data(bytes: fingerprintBytes))
            
            let subpackets:[SignatureSubpacketable] = [SignatureCreated(date: pgpPublicKey.created), PGPFormat.SignatureKeyFlags(flagTypes: [PGPFormat.KeyFlagType.signData])]

            let dataToHash = try pubKeyToSign.dataToHash(hashAlgorithm: PGPFormat.Signature.HashAlgorithm.sha512, hashedSubpacketables: subpackets)
            
            let hash = dataToHash.SHA512
            
            let signedHashBytes = try keypair.sign(data: hash, digestType: DigestType.ed25519).bytes
            let signedHash = Data(bytes: signedHashBytes)
            
            let signedPublicKey = try pubKeyToSign.signedPublicKey(hash: hash, hashAlgorithm: PGPFormat.Signature.HashAlgorithm.sha512, hashedSubpacketables: subpackets, signatureData: signedHash)
            
            let outMsg = try PGPFormat.AsciiArmorMessage(packets: signedPublicKey.toPackets(), blockType: PGPFormat.ArmorMessageBlock.publicKey).toString()
            print(outMsg)
            
            let packets = try [Packet](data: PGPFormat.AsciiArmorMessage(string: outMsg).packetData)
            let _ = try PGPFormat.PublicKey(packet: packets[0])
            let _ = try PGPFormat.UserID(packet: packets[1])
            let _ = try PGPFormat.Signature(packet: packets[2])
            
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }

    
    func testVerifyEd25519PublicKey() {
        
        let bundle = Bundle(for: type(of: self))
        let pubkeyEd25519 = try! String(contentsOfFile: bundle.path(forResource: "pubkey_ed25519", ofType: "txt")!)

        do  {
            let pubMsg = try AsciiArmorMessage(string: pubkeyEd25519)
            let packets = try [Packet](data: pubMsg.packetData)
            
            let publicKey = try PGPFormat.PublicKey(packet: packets[0])
            let userID = try UserID(packet: packets[1])
            let signature = try Signature(packet: packets[2])
            
            let pubKeyToSign = PublicKeyIdentityToSign(publicKey: publicKey, userID: userID)
            
            let dataToHash = try pubKeyToSign.dataToHash(hashAlgorithm: signature.hashAlgorithm, hashedSubpacketables: signature.hashedSubpacketables)
            
            var hash:Data
            
            switch signature.hashAlgorithm {
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
            
            let leftTwoBytes = [UInt8](hash.bytes[0...1])
            
            guard leftTwoBytes == signature.leftTwoHashBytes else {
                XCTFail("Left two hash bytes don't match: \nGot: \(leftTwoBytes)\nExpected: \(signature.leftTwoHashBytes)")
                return
            }
            
            let edPubKey = (publicKey.publicKeyData as! ECCPublicKey).rawData as Sign.PublicKey
                        
            guard try edPubKey.verify(hash, signature: signature.signature, digestType: DigestType.ed25519) else {
                XCTFail("signature doesn't match!")
                return
            }
            
            
        } catch {
            XCTFail("Unexpected error: \(error)")
            
        }
    }
}
