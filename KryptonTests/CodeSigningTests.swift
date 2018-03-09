//
//  CodeSigningTests.swift
//  Krypton
//
//  Created by Alex Grinman on 5/19/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

import XCTest
@testable import Krypton

import PGPFormat
import Sodium

class CodeSigningTests: XCTestCase {
    
    var keypairClasses:[KeyPair.Type] = []
    var publicKeyClasses:[Krypton.PublicKey.Type] = []
    var hashAlgorithms:[Signature.HashAlgorithm] = [.sha1, .sha224, .sha256, .sha384, .sha512]

    class UnsafeNISTP256KeyPair:NISTP256KeyPair {
        override class var useSecureEnclave:Bool { return false }
    }
    
    override func setUp() {
        keypairClasses = [RSAKeyPair.self, Ed25519KeyPair.self]
        
        if Platform.isSimulator {
            keypairClasses.append(UnsafeNISTP256KeyPair.self)
        } else {
            keypairClasses.append(NISTP256KeyPair.self)
        }
        
        publicKeyClasses = [RSAPublicKey.self, Sign.PublicKey.self, NISTP256PublicKey.self]
        super.setUp()
    }
    

    override func tearDown() {
        super.tearDown()
    }
    
    func testCreatePGPPublicKeys() {
        for KPClass in keypairClasses {
            log("Testing \(KPClass)")
            
            for hashAlgorithm in hashAlgorithms {
                log("Testing hash algorithm \(hashAlgorithm)")

                do {
                    try KPClass.destroy("test")
                    let keypair = try KPClass.generate("test")
                    
                    // rsa
                    if let (m,_) = try (keypair.publicKey as? Krypton.RSAPublicKey)?.splitIntoComponents() {
                        if m.bytes[0] != 0x00 {
                            XCTFail("first byte not 0!!!!")
                            return
                        }
                    }
                    
                    let armoredPubKey = try keypair.exportAsciiArmoredPGPPublicKey(for: "alex test <alex@test.com>", hashAlgorithm: hashAlgorithm)
                    print(armoredPubKey.toString())
                    
                    let packets  = try [Packet](data: armoredPubKey.packetData)
                    
                    let _ = try PGPFormat.PublicKey(packet: packets[0])
                    let _ = try PGPFormat.UserID(packet: packets[1])
                    let _ = try PGPFormat.Signature(packet: packets[2])
                    
                } catch (let e) {
                    if let ce = e as? CryptoError {
                        XCTFail("test failed: \(ce.getError())")
                    } else {
                        XCTFail("\(e)")
                    }
                }

            }

        }
    }
    
    func testVerifyPGPPublicKey() {
        
        for (_, KPClass) in keypairClasses.enumerated() {
            log("Testing \(KPClass)")
            
            for hashAlgorithm in hashAlgorithms {
                log("Testing hash algorithm \(hashAlgorithm)")

                do  {
                    try KPClass.destroy("test")
                    let keypair = try KPClass.generate("test")
                                        
                    let packets = try [Packet](data: keypair.exportAsciiArmoredPGPPublicKey(for: "alex test <alex@test.com>", hashAlgorithm: hashAlgorithm).packetData)
                    
                    let publicKey = try PGPFormat.PublicKey(packet: packets[0])
                    let userID = try PGPFormat.UserID(packet: packets[1])
                    let signature = try Signature(packet: packets[2])
                    
                    var pubKeyToSign = try SignedPublicKeyIdentity(publicKey: publicKey, userID: userID, hashAlgorithm: signature.hashAlgorithm, hashedSubpacketables: signature.hashedSubpacketables)
                    
                    let dataToHash = try pubKeyToSign.dataToHash()
                    
                    var hash:Data
                    var digestType:DigestType
                    
                    switch signature.hashAlgorithm {
                    case .sha1:
                        hash = dataToHash.SHA1
                        digestType = .sha1
                    case .sha224:
                        hash = dataToHash.SHA224
                        digestType = .sha224
                    case .sha256:
                        hash = dataToHash.SHA256
                        digestType = .sha256
                    case .sha384:
                        hash = dataToHash.SHA384
                        digestType = .sha384
                    case .sha512:
                        hash = dataToHash.SHA512
                        digestType = .sha512
                    }
                    
                    try pubKeyToSign.set(hash: hash, signedHash: signature.signature)
                    
                    guard pubKeyToSign.signature.leftTwoHashBytes == signature.leftTwoHashBytes else {
                        XCTFail("Left two hash bytes don't match: \nGot: \(pubKeyToSign.signature.leftTwoHashBytes)\nExpected: \(signature.leftTwoHashBytes)")
                        return
                    }
                    
                    var sig = Data()
                    for sigComp in signature.signature {
                        sig += sigComp
                    }
                    
                    // special case for ed25519 verification
                    if KPClass == Ed25519KeyPair.self {
                        guard try keypair.publicKey.verify(hash, signature: sig, digestType: .ed25519)
                            else {
                                XCTFail("signature doesn't match!")
                                return
                        }

                    } else if keypair.publicKey is NISTP256PublicKey {
                        //TODO: implementing wrapping split r,s in asn1
                    }
                    else {
                        guard try keypair.publicKey.verify(dataToHash, signature: sig, digestType: digestType)
                            else {
                                XCTFail("signature doesn't match!")
                                return
                        }

                    }
                    
                    
                } catch {
                    XCTFail("Unexpected error: \(error)")
                    
                }

            }

        }
        
    }
    
    func testComputeCommitHash() {
        do  {
            let sigMessage = try Message(base64: "iF4EABYKAAYFAlkkmD8ACgkQ4eT0x9ceFp1gNQD+LWiJFax8iQqgr0yJ1P7JFGvMwuZc8r05h6U+X+lyKYEBAK939lEX1rvBmcetftVbRlOMX5oQZwBLt/NJh+nQ3ssC")
            let commitInfo = try CommitInfo(tree: "2c4df4a89ac5b0b8b21fd2aad4d9b19cd91e7049",
                                        parent: "1cd97d0545a25c578e3f4da5283106606276eadf",
                                        mergeParents: nil,
                                        author: "Alex Grinman <alex@krypt.co> 1495570495 -0400",
                                        committer: "Alex Grinman <alex@krypt.co> 1495570495 -0400",
                                        message: "\ntest1234\n".utf8Data())
            
            let asciiArmored = AsciiArmorMessage(message: sigMessage, blockType: ArmorMessageBlock.signature, comment: "Created With Kryptonite").toString()
            
            let commitHash = try commitInfo.commitHash(asciiArmoredSignature: asciiArmored).hex
            
            guard commitHash == "84e09dac58d81b1f3fc4806b1b4cb18af3cca0ea" else {
                XCTFail("Commit hash does not match, got: \(commitHash)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
            
        }
    }
    
    func testPGPUserIDs() {
        
        // test max init
        var users = UserIDList(ids: ["alice", "bob", "eve", "alex"])
        if users.ids.count > 3 {
            XCTFail("too many user ids: \(users.ids.count)")
        }
        
        if users.ids != ["alice", "bob", "eve"]{
            XCTFail("incorrect user_ids: \(users.ids)")
        }

        
        // test max updating
        users = UserIDList(ids: ["alice", "bob"])
        users = users.by(updating: "eve")
        users = users.by(updating: "alex")
        
        if users.ids.count != 3 {
            XCTFail("incorrect number of user ids: \(users.ids.count)")
        }

        
        // test order updating
        users = UserIDList(ids: [])
        users = users.by(updating: "eve")
        users = users.by(updating: "alex")
        users = users.by(updating: "bob")
        
        if users.ids != ["bob", "alex", "eve"] {
            XCTFail("invalid order of user ids: \(users.ids)")
        }
        
        // update existing one
        users = users.by(updating: "eve")
        if users.ids != ["eve", "bob", "alex"] {
            XCTFail("invalid order of user ids: \(users.ids)")
        }
        
        // add new one
        users = users.by(updating: "alice")
        if users.ids != ["alice", "eve", "bob"] {
            XCTFail("invalid order of user ids: \(users.ids)")
        }
        
        // update existing one
        users = users.by(updating: "bob")
        if users.ids != ["bob", "alice", "eve"] {
            XCTFail("invalid order of user ids: \(users.ids)")
        }
        
        // add new one, not full
        users = UserIDList(ids: ["alice", "bob"])
        users = users.by(updating: "eve")
        if users.ids != ["eve", "alice", "bob"] {
            XCTFail("invalid order of user ids: \(users.ids)")
        }


    }
}
