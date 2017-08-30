//
//  CodeSigningTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/19/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

import XCTest
@testable import Kryptonite

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
            try RSAKeyPair.destroy("test")
            let keypair = try RSAKeyPair.generate("test")

            let armoredPubKey = try keypair.exportAsciiArmoredPGPPublicKey(for: "alex test <alex@test.com>")
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
    
    func testCreatePGPPublicKeyEd25519(i:Int) {
        do {
            try Ed25519KeyPair.destroy("test")
            let keypair = try Ed25519KeyPair.generate("test")

            let armoredPubKey = try keypair.exportAsciiArmoredPGPPublicKey(for: "alex test <alex@test.com>")

            let packets  = try [Packet](data: armoredPubKey.packetData)
            
            let _ = try PGPFormat.PublicKey(packet: packets[0])
            let _ = try PGPFormat.UserID(packet: packets[1])
            let _ = try PGPFormat.Signature(packet: packets[2])

        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                print("failed at \(i)")
                XCTFail("\(e)")
            }
        }
    }
    
    func testVerifyRSAPublicKey() {
        
        do  {
            try RSAKeyPair.destroy("test")
            let keypair = try RSAKeyPair.generate("test")
            let packets = try [Packet](data: keypair.exportAsciiArmoredPGPPublicKey(for: "alex test <alex@test.com>").packetData)
            
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
            
            
            guard try keypair.publicKey.verify(dataToHash, signature: signature.signature, digestType: digestType)
            else {
                XCTFail("signature doesn't match!")
                return
            }
            
        } catch {
            XCTFail("Unexpected error: \(error)")
            
        }
    }


    
    func testVerifyEd25519PublicKey() {
        do  {
            try Ed25519KeyPair.destroy("test")
            let keypair = try Ed25519KeyPair.generate("test")
            let packets = try [Packet](data: keypair.exportAsciiArmoredPGPPublicKey(for: "alex test <alex@test.com>").packetData)
            
            let publicKey = try PGPFormat.PublicKey(packet: packets[0])
            let userID = try PGPFormat.UserID(packet: packets[1])
            let signature = try Signature(packet: packets[2])
            
            var pubKeyToSign = try SignedPublicKeyIdentity(publicKey: publicKey, userID: userID, hashAlgorithm: signature.hashAlgorithm, hashedSubpacketables: signature.hashedSubpacketables)
            
            let dataToHash = try pubKeyToSign.dataToHash()
            
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
            
            try pubKeyToSign.set(hash: hash, signedHash: signature.signature)
            
            guard pubKeyToSign.signature.leftTwoHashBytes == signature.leftTwoHashBytes else {
                XCTFail("Left two hash bytes don't match: \nGot: \(pubKeyToSign.signature.leftTwoHashBytes)\nExpected: \(signature.leftTwoHashBytes)")
                return
            }
            
            guard try keypair.publicKey.verify(hash, signature: signature.signature, digestType: DigestType.ed25519)
            else {
                XCTFail("signature doesn't match!")
                return
            }
            
        } catch {
            XCTFail("Unexpected error: \(error)")
            
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
