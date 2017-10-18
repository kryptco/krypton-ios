//
//  Response+Team.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import Sodium

// Create

struct TeamCheckpoint:Jsonable {
    let publicKey:SodiumSignPublicKey
    let teamPublicKey:SodiumSignPublicKey
    let lastBlockHash:Data
    
    init(publicKey:SodiumSignPublicKey, teamPublicKey:SodiumSignPublicKey, lastBlockHash:Data) {
        self.publicKey = publicKey
        self.teamPublicKey = teamPublicKey
        self.lastBlockHash = lastBlockHash
    }
    
    init(json:Object) throws {
        try self.init(publicKey: ((json ~> "public_key") as String).fromBase64(),
                      teamPublicKey: ((json ~> "team_public_key") as String).fromBase64(),
                      lastBlockHash: ((json ~> "last_block_hash") as String).fromBase64())
    }
    
    var object:Object {
        return ["public_key": publicKey.toBase64(),
                "team_public_key": teamPublicKey.toBase64(),
                "last_block_hash": lastBlockHash.toBase64()]
    }
}

// Read

struct ReadTeamResponse:Jsonable {
    let token:String // string of ReadToken
    let signature:Data
    
    init(token:String, signature:Data) {
        self.token = token
        self.signature = signature
    }
    
    init(json:Object) throws {
        try self.init(token: json ~> "token",
                      signature: ((json ~> "signature") as String).fromBase64())
    }
    
    var object:Object {
        return ["token": token,
                "signature": signature.toBase64()]
    }
}

enum ReadToken:Jsonable {
    case time(TimeToken)
    
    init(json: Object) throws {
        self = try .time(TimeToken(json: json ~> "time"))
    }
    
    var object: Object {
        switch self {
        case .time(let timeToken):
            return ["time": timeToken.object]
        }
    }
}

struct TimeToken:Jsonable {
    let publicKey:SodiumSignPublicKey
    let expiration:UInt64
    
    init(publicKey:SodiumSignPublicKey, expiration:UInt64) {
        self.publicKey = publicKey
        self.expiration = expiration
    }
    
    init(json:Object) throws {
        try self.init(publicKey: ((json ~> "public_key") as String).fromBase64(),
                      expiration: json ~> "expiration")
    }
    
    var object:Object {
        return ["public_key": publicKey.toBase64(),
                "expiration": expiration]
    }
}

// Team Operation

struct TeamOperationResponse:Jsonable {
    let postedBlockHash:Data
    
    init(postedBlockHash:Data) {
        self.postedBlockHash = postedBlockHash
    }
    
    init(json:Object) throws {
        try self.init(postedBlockHash: ((json ~> "posted_block_hash") as String).fromBase64())
    }
    
    var object:Object {
        return ["posted_block_hash": postedBlockHash.toBase64()]
    }
}

// Log Decryption

struct LogDecryptionResponse:Jsonable {
    let logDecryptionKey:SodiumSecretBoxKey
    
    init(logDecryptionKey:SodiumSecretBoxKey) {
        self.logDecryptionKey = logDecryptionKey
    }
    
    init(json:Object) throws {
        try self.init(logDecryptionKey: ((json ~> "log_decryption_key") as String).fromBase64())
    }
    
    var object:Object {
        return ["log_decryption_key": logDecryptionKey.toBase64()]
    }
}


