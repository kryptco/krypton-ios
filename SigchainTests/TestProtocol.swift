//
//  TestProtocol.swift
//  SigchainTests
//
//  Created by Alex Grinman on 2/12/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

import JSON
@testable import Krypton

struct BlockValidationTest {
    let testBlocks:[TestBlock]
    let name:String
    let clients:[Client]
}

struct TestBlock {
    let signedMessage:SigChain.SignedMessage
    let expected:ExpectedResult
}

struct ExpectedResult {
    let valid:Bool
    let teamPublicKey:SodiumSignPublicKey
}

struct Client {
    let signKeyPairSeed:Data
    let teamPublicKey:SodiumSignPublicKey
}


// Mark: Extension Helpers

extension TeamIdentity {
    init(client: Client) throws {
        let id = try Data.random(size: 32)
        let teamID = try Data.random(size: 32)
        let keyPairSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        let boxKeyPairSeed = try Data.random(size: KRSodium.instance().box.SeedBytes)
                
        let mutableData = MutableData(checkpoint: Data())
        
        try self.init(id: id,
                  email: "test@krypt.co",
                  keyPairSeed: keyPairSeed,
                  boxKeyPairSeed: boxKeyPairSeed,
                  teamID: teamID,
                  initialTeamPublicKey: client.teamPublicKey,
                  mutableData: mutableData)
    }
}

// Mark: JSON Deserialization

extension BlockValidationTest:JsonReadable {
    init(json: Object) throws {
        testBlocks = try [TestBlock](json: json ~> "blocks")
        name = try json ~> "name"
        clients = try [Client](json: json ~> "clients")
    }
}

extension TestBlock:JsonReadable {
    init(json: Object) throws {
        signedMessage = try SigChain.SignedMessage(json: json ~> "signed_message")
        expected = try ExpectedResult(json: json ~> "expected")
    }
}

extension ExpectedResult:JsonReadable {
    init(json: Object) throws {
        valid = try json ~> "valid"
        teamPublicKey = try ((json ~> "team_public_key") as String).fromBase64()
    }
}

extension Client:JsonReadable {
    init(json: Object) throws {
        signKeyPairSeed = try ((json ~> "sign_key_pair_seed") as String).fromBase64()
        teamPublicKey = try ((json ~> "team_public_key") as String).fromBase64()
    }
}

