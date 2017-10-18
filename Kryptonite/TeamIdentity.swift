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
    let keyPair:SodiumSignKeyPair
    let encryptionKeyPair:SodiumBoxKeyPair
    let initialTeamPublicKey:SodiumSignPublicKey
    var email:String

    private let keyPairSeed:Data
    private let boxKeyPairSeed:Data
    private let teamID:Data
    
    // Mutable Team Identity Data
    var mutableData:MutableData
    
    var checkpoint:Data {
        get {
            return mutableData.checkpoint
        }
        set(c) {
            mutableData.checkpoint = c
        }
    }
    
    var logCheckpoint:Data? {
        get {
            return mutableData.logCheckpoint
        }
        set(lc) {
            mutableData.logCheckpoint = lc
        }
    }
    
    var logEncryptionKey:SodiumSecretBoxKey {
        get {
            return mutableData.logEncryptionKey
        }
        set(le) {
            mutableData.logEncryptionKey = le
        }
    }
    
    struct MutableData:Jsonable {
        var checkpoint:Data
        var logCheckpoint:Data?
        var logEncryptionKey:SodiumSecretBoxKey
        
        init(checkpoint:Data, logCheckpoint:Data?, logEncryptionKey:SodiumSecretBoxKey) {
            self.checkpoint = checkpoint
            self.logCheckpoint = logCheckpoint
            self.logEncryptionKey = logEncryptionKey
        }
        init(json: Object) throws {
            let logCheckpoint:Data? = try? ((json ~> "log_checkpoint") as String).fromBase64()
            try self.init( checkpoint: ((json ~> "checkpoint") as String).fromBase64(),
                           logCheckpoint: logCheckpoint,
                           logEncryptionKey: ((json ~> "log_encryption_key") as String).fromBase64())

        }
        
        var object: Object {
            var object:Object = ["checkpoint": checkpoint.toBase64(),
                                 "log_encryption_key": logEncryptionKey.toBase64()]
            
            if let logCheckpoint = logCheckpoint {
                object["log_checkpoint"] = logCheckpoint.toBase64()
            }
            
            return object

        }
    }

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
        
    func lastBlockHash() throws -> Data? {
        return try dataManager.lastBlockHash()
    }
    
    /**
        Create a new identity with an email for use with `team`
     */
    static func newAdmin(email:String, teamName:String) throws -> (TeamIdentity, SigChain.Block) {
        let id = try Data.random(size: 32)
        let teamID = try Data.random(size: 32)
        let keyPairSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        let boxKeyPairSeed = try Data.random(size: KRSodium.instance().box.SeedBytes)

        guard let keyPair = KRSodium.instance().sign.keyPair(seed: keyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        
        guard let boxKeyPair = KRSodium.instance().box.keyPair(seed: boxKeyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        
        guard let logEncryptionKey = KRSodium.instance().secretBox.key() else {
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
        let createChain = SigChain.CreateChain(creator: creator, teamInfo: Team.Info(name: teamName))
        let payload = SigChain.Payload.createChain(createChain)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: keyPair.secretKey)
        else {
            throw Errors.signingError
        }
        
        // create the block
        let createBlock = try SigChain.Block(publicKey: keyPair.publicKey, payload: payloadData.utf8String(), signature: signature)
        let checkpoint = createBlock.hash()
        
        let mutableData = MutableData(checkpoint: checkpoint, logCheckpoint: nil, logEncryptionKey: logEncryptionKey)
        
        // make the team identity + team
        let teamIdentity = try TeamIdentity(id: id, email: email, keyPairSeed: keyPairSeed, boxKeyPairSeed: boxKeyPairSeed, teamID: teamID, initialTeamPublicKey: keyPair.publicKey, mutableData: mutableData)
        try teamIdentity.dataManager.create(team: Team(info: Team.Info(name: teamName)), creator: creator, block: createBlock)
        
        return (teamIdentity, createBlock)
    }

    static func newMember(email:String, teamName:String = "", checkpoint:Data, initialTeamPublicKey:SodiumSignPublicKey) throws -> TeamIdentity {
        let id = try Data.random(size: 32)
        let teamID = try Data.random(size: 32)
        let keyPairSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        let boxKeyPairSeed = try Data.random(size: KRSodium.instance().box.SeedBytes)

        guard let logEncryptionKey = KRSodium.instance().secretBox.key() else {
            throw Errors.secretBoxKey
        }
        
        let mutableData = MutableData(checkpoint: checkpoint, logCheckpoint: nil, logEncryptionKey: logEncryptionKey)

        return try TeamIdentity(id: id, email: email, keyPairSeed: keyPairSeed, boxKeyPairSeed: boxKeyPairSeed, teamID: teamID, initialTeamPublicKey: initialTeamPublicKey, mutableData: mutableData)
    }
    
    private init(id:Data, email:String, keyPairSeed:Data, boxKeyPairSeed:Data, teamID:Data, initialTeamPublicKey:SodiumSignPublicKey, mutableData:MutableData) throws {
        self.id = id
        self.email = email
        self.keyPairSeed = keyPairSeed
        self.boxKeyPairSeed = boxKeyPairSeed
        
        guard let keyPair = KRSodium.instance().sign.keyPair(seed: keyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        self.keyPair = keyPair
        
        guard let boxKeyPair = KRSodium.instance().box.keyPair(seed: boxKeyPairSeed) else {
            throw Errors.keyPairFromSeed
        }
        
        self.encryptionKeyPair = boxKeyPair
        
        self.mutableData = mutableData

        self.teamID = teamID
        self.initialTeamPublicKey = initialTeamPublicKey
        self.dataManager = try TeamDataManager(teamID: teamID)
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
                      initialTeamPublicKey: ((json ~> "inital_team_public_key") as String).fromBase64(),
                      mutableData: MutableData(json: json ~> "mutable_data"))
    }
    
    var object: Object {
        let object:Object = ["id": id.toBase64(),
                             "email": email,
                             "keypair_seed": keyPairSeed.toBase64(),
                             "box_keypair_seed": boxKeyPairSeed.toBase64(),
                             "team_id": teamID.toBase64(),
                             "inital_team_public_key": initialTeamPublicKey.toBase64()]
        
        return object
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

