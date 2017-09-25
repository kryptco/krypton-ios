//
//  Identity.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium
import JSON

struct TeamIdentity:Jsonable {
    let id:Data
    var email:String
    let keyPair:SodiumSignKeyPair
    let encryptionKeyPair:SodiumBoxKeyPair

    private let keyPairSeed:Data
    private let boxKeyPairSeed:Data

    private let teamID:Data
    var checkpoint:Data
    
    let initialTeamPublicKey:SodiumSignPublicKey

    var logCheckpoint:Data?
    var logEncryptionKey:SodiumSecretBoxKey

    /**
        Team Persistance
     */
    var dataManager:TeamDataManager
    
    func set(team:Team) throws {
        try dataManager.set(team: team)
    }
    
    func team() throws -> Team {
        return try dataManager.fetchTeam()
    }
    
    enum Errors:Error {
        case keyPairFromSeed
        case signingError
        case secretBoxKey
    }
    
    var createTeamResponse:CreateTeamResponse {
        let keyAndTeamCheckpoint = KeyAndTeamCheckpoint(seed: keyPairSeed, teamPublicKey: initialTeamPublicKey, lastBlockHash: checkpoint)
        return CreateTeamResponse(keyAndTeamCheckpoint: keyAndTeamCheckpoint, error: nil)
    }
    
    var adminKeyResponse:AdminKeyResponse {
        let keyAndTeamCheckpoint = KeyAndTeamCheckpoint(seed: keyPairSeed, teamPublicKey: initialTeamPublicKey, lastBlockHash: checkpoint)
        return AdminKeyResponse(keyAndTeamCheckpoint: keyAndTeamCheckpoint, error: nil)
    }

    
    func lastBlockHash() throws -> Data? {
        return try dataManager.lastBlockHash()
    }
    
    /**
        Create a new identity with an email for use with `team`
     */
    static func newAdmin(email:String, teamName:String) throws -> (TeamIdentity, HashChain.Block) {
        let id = try Data.random(size: 32)
        let teamID = try Data.random(size: 32)
        let keyPairSeed = try Data.random(size: KRSodium.shared().sign.SeedBytes)
        let boxKeyPairSeed = try Data.random(size: KRSodium.shared().box.SeedBytes)

        guard let keyPair = try KRSodium.shared().sign.keyPair(seed: keyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        
        guard let boxKeyPair = try KRSodium.shared().box.keyPair(seed: boxKeyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        
        guard let logEncryptionKey = try KRSodium.shared().secretBox.key() else {
            throw Errors.secretBoxKey
        }
        
        // create the creator's identity
        let sshPublicKey = try KeyManager.sharedInstance().keyPair.publicKey.wireFormat()
        let pgpPublicKey = try KeyManager.sharedInstance().loadPGPPublicKey(for: email).packetData
        let creator = Team.MemberIdentity(publicKey: keyPair.publicKey,
                                          encryptionPublicKey: boxKeyPair.publicKey,
                                          email: email,
                                          sshPublicKey: sshPublicKey,
                                          pgpPublicKey: pgpPublicKey)

        
        // create the first block
        let createChain = HashChain.CreateChain(creator: creator, teamInfo: Team.Info(name: teamName))
        let payload = HashChain.Payload.createChain(createChain)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: keyPair.secretKey)
        else {
            throw Errors.signingError
        }
        
        // create the block
        let createBlock = try HashChain.Block(publicKey: keyPair.publicKey, payload: payloadData.utf8String(), signature: signature)
        let checkpoint = createBlock.hash()

        // make the team identity + team
        let teamIdentity = try TeamIdentity(id: id, email: email, keyPairSeed: keyPairSeed, boxKeyPairSeed: boxKeyPairSeed, teamID: teamID, checkpoint: checkpoint, initialTeamPublicKey: keyPair.publicKey, logEncryptionKey: logEncryptionKey)
        try teamIdentity.dataManager.create(team: Team(info: Team.Info(name: teamName)), creator: creator, block: createBlock)
        
        return (teamIdentity, createBlock)
    }

    static func newMember(email:String, teamName:String = "", checkpoint:Data, initialTeamPublicKey:SodiumSignPublicKey) throws -> TeamIdentity {
        let id = try Data.random(size: 32)
        let teamID = try Data.random(size: 32)
        let keyPairSeed = try Data.random(size: KRSodium.shared().sign.SeedBytes)
        let boxKeyPairSeed = try Data.random(size: KRSodium.shared().box.SeedBytes)

        guard let logEncryptionKey = try KRSodium.shared().secretBox.key() else {
            throw Errors.secretBoxKey
        }

        return try TeamIdentity(id: id, email: email, keyPairSeed: keyPairSeed, boxKeyPairSeed: boxKeyPairSeed, teamID: teamID, checkpoint: checkpoint, initialTeamPublicKey: initialTeamPublicKey, logEncryptionKey: logEncryptionKey)
    }
    
    private init(id:Data, email:String, keyPairSeed:Data, boxKeyPairSeed:Data, teamID:Data, checkpoint:Data, initialTeamPublicKey:SodiumSignPublicKey, logEncryptionKey:SodiumSecretBoxKey) throws {
        self.id = id
        self.email = email
        self.keyPairSeed = keyPairSeed
        self.boxKeyPairSeed = boxKeyPairSeed
        
        guard let keyPair = try KRSodium.shared().sign.keyPair(seed: keyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        self.keyPair = keyPair
        
        guard let boxKeyPair = try KRSodium.shared().box.keyPair(seed: boxKeyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        self.encryptionKeyPair = boxKeyPair
        self.logEncryptionKey = logEncryptionKey
        
        self.teamID = teamID
        self.checkpoint = checkpoint
        self.initialTeamPublicKey = initialTeamPublicKey
        self.dataManager = TeamDataManager(teamID: teamID)
    }
    
    init(json: Object) throws {
        let teamID:Data = try ((json ~> "team_id") as String).fromBase64()
        let keyPairSeed:Data = try ((json ~> "keypair_seed") as String).fromBase64()
        let boxKeyPairSeed:Data = try ((json ~> "box_keypair_seed") as String).fromBase64()


        try self.init(id: ((json ~> "id") as String).fromBase64(),
                      email: json ~> "email",
                      keyPairSeed: keyPairSeed,
                      boxKeyPairSeed: boxKeyPairSeed,
                      teamID: teamID,
                      checkpoint: ((json ~> "checkpoint") as String).fromBase64(),
                      initialTeamPublicKey: ((json ~> "inital_team_public_key") as String).fromBase64(),
                      logEncryptionKey: ((json ~> "log_encryption_key") as String).fromBase64())
    }
    
    var object: Object {
        return    ["id": id.toBase64(),
                   "email": email,
                   "keypair_seed": keyPairSeed.toBase64(),
                   "box_keypair_seed": boxKeyPairSeed.toBase64(),
                   "team_id": teamID.toBase64(),
                   "checkpoint": checkpoint.toBase64(),
                   "inital_team_public_key": initialTeamPublicKey.toBase64()]
        
    }
    
    
    /** 
        Chain Validity
     */
    
    func isCheckPointReached() throws -> Bool {
        return try dataManager.hasBlock(for: checkpoint)
    }
    
    /**
        Is Admin
     */
    func isAdmin() throws -> Bool {
        return try dataManager.isAdmin(for: keyPair.publicKey)
    }
}

