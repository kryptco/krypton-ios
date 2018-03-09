//
//  Identity.swift
//  Krypton
//
//  Created by Alex Grinman on 7/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium
import JSON

struct TeamIdentity:Jsonable {
    let id:Data
    
    // identity/signing
    private let keyPair:SodiumSignKeyPair
    
    var publicKey:SodiumSignPublicKey {
        return self.keyPair.publicKey
    }
    
    // encryption
    private let encryptionKeyPair:SodiumBoxKeyPair
    
    var encryptionPublicKey:SodiumBoxPublicKey {
        return encryptionKeyPair.publicKey
    }
    
    let initialTeamPublicKey:SodiumSignPublicKey
    var email:String

    private let keyPairSeed:Data
    private let boxKeyPairSeed:Data
    private let teamID:Data
    
    // Mutable Team Identity Data
    var mutableData:MutableData
    
    /**
        Chain Validity
     */
    var checkpoint:Data {
        get {
            return mutableData.checkpoint
        }
        set(c) {
            mutableData.checkpoint = c
        }
    }
    
    struct MutableData:Jsonable {
        var checkpoint:Data
        
        init(checkpoint:Data) {
            self.checkpoint = checkpoint
        }
        init(json: Object) throws {
            try self.init(checkpoint: ((json ~> "checkpoint") as String).fromBase64())
        }
        
        var object: Object {
            return ["checkpoint": checkpoint.toBase64()]
        }
    }
    
    /**
        Signing (ensure only inside-struct use of `keyPair`)
     */
    func sign(message:SigChain.Message) throws -> SigChain.SignedMessage {
        let messageData = try message.jsonData()
        guard let signature = KRSodium.instance().sign.signature(message: messageData, secretKey: keyPair.secretKey) else {
            throw Errors.signingError
        }
        
        let serializedMessage = try messageData.utf8String()
        
        return SigChain.SignedMessage(publicKey: self.publicKey, message: serializedMessage, signature: signature)
    }
    
    /**
        Box sealing (ensure only inside struct use of `encryptionKeyPair`)
    */
    func seal(plaintextBody:SigChain.PlaintextBody, recipientPublicKey:SodiumBoxPublicKey) throws -> SigChain.BoxedMessage {
        let plaintextData = try plaintextBody.jsonData()
        
        guard let ciphertext:Data = KRSodium.instance().box.seal(message: plaintextData,
                                                            recipientPublicKey: recipientPublicKey,
                                                            senderSecretKey: self.encryptionKeyPair.secretKey)
        else {
            throw Errors.sealingError
        }

        return SigChain.BoxedMessage(recipientPublicKey: recipientPublicKey,
                                     senderPublicKey: self.encryptionPublicKey,
                                     ciphertext: ciphertext)
    }
    
    func open(boxedMessage:SigChain.BoxedMessage) throws -> SigChain.PlaintextBody {
        guard let plaintext = KRSodium.instance().box.open(nonceAndAuthenticatedCipherText: boxedMessage.ciphertext,
                                                           senderPublicKey: boxedMessage.senderPublicKey,
                                                           recipientSecretKey: self.encryptionKeyPair.secretKey)
        else {
            throw Errors.openingError
        }
        
        return try SigChain.PlaintextBody(jsonData: plaintext)
    }

    /**
        Team Persistence
     */
    var dataManager:TeamDataTransaction {
        return TeamDataTransaction(identity: self)
    }
    
    enum Errors:Error {
        case keyPairFromSeed
        case signingError
        case sealingError
        case openingError
        case secretBoxKey
    }
    
    /**
        Create a new identity with an email for use with `team`
     */
    static func newAdmin(email:String, teamName:String) throws -> (TeamIdentity, SigChain.SignedMessage) {
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
        
        // create the creator's identity
        let sshPublicKey = try KeyManager.sharedInstance().keyPair.publicKey.wireFormat()
        let pgpPublicKey = try KeyManager.sharedInstance().loadPGPPublicKey(for: email).packetData
        let creator = SigChain.Identity(publicKey: keyPair.publicKey,
                                          encryptionPublicKey: boxKeyPair.publicKey,
                                          email: email,
                                          sshPublicKey: sshPublicKey,
                                          pgpPublicKey: pgpPublicKey)

        
        // create the first block
        let genesisBlock = SigChain.GenesisBlock(creator: creator, teamInfo: SigChain.TeamInfo(name: teamName))
        let message = SigChain.Message(body: .main(.create(genesisBlock)))
        let messageData = try message.jsonData()
        
        // sign the message
        guard let signature = KRSodium.instance().sign.signature(message: messageData, secretKey: keyPair.secretKey)
        else {
            throw Errors.signingError
        }
        
        // create the signed message
        let signedMessage = try SigChain.SignedMessage(publicKey: keyPair.publicKey, message: messageData.utf8String(), signature: signature)
        let checkpoint = signedMessage.hash()
        
        let mutableData = MutableData(checkpoint: checkpoint)
        
        // make the team identity + team
        let teamIdentity = try TeamIdentity(id: id, email: email, keyPairSeed: keyPairSeed, boxKeyPairSeed: boxKeyPairSeed, teamID: teamID, initialTeamPublicKey: keyPair.publicKey, mutableData: mutableData)
        try teamIdentity.dataManager.withTransaction{ try $0.create(team: Team(info: SigChain.TeamInfo(name: teamName)), creator: creator, block: signedMessage) }
        
        return (teamIdentity, signedMessage)
    }

    static func newMember(email:String, checkpoint:Data, initialTeamPublicKey:SodiumSignPublicKey) throws -> TeamIdentity {
        let id = try Data.random(size: 32)
        let teamID = try Data.random(size: 32)
        let keyPairSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        let boxKeyPairSeed = try Data.random(size: KRSodium.instance().box.SeedBytes)
        
        let mutableData = MutableData(checkpoint: checkpoint)

        return try TeamIdentity(id: id, email: email, keyPairSeed: keyPairSeed, boxKeyPairSeed: boxKeyPairSeed, teamID: teamID, initialTeamPublicKey: initialTeamPublicKey, mutableData: mutableData)
    }
    
    init(id:Data, email:String, keyPairSeed:Data, boxKeyPairSeed:Data, teamID:Data, initialTeamPublicKey:SodiumSignPublicKey, mutableData:MutableData) throws {
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
                      initialTeamPublicKey: ((json ~> "initial_team_public_key") as String).fromBase64(),
                      mutableData: MutableData(json: json ~> "mutable_data"))
    }
    
    var object: Object {
        let object:Object = ["id": id.toBase64(),
                             "email": email,
                             "keypair_seed": keyPairSeed.toBase64(),
                             "box_keypair_seed": boxKeyPairSeed.toBase64(),
                             "team_id": teamID.toBase64(),
                             "initial_team_public_key": initialTeamPublicKey.toBase64()]
        
        return object
    }
    

    
    /**
        Is Admin
     */
    func isAdmin(dataManager:TeamDataManager) throws -> Bool {
        return try dataManager.isAdmin(for: self.publicKey)
    }
}

