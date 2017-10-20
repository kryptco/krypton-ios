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
    let signerPublicKey:SodiumSignPublicKey
    let token:String // string of ReadToken
    let signature:Data
    
    init(signerPublicKey:SodiumSignPublicKey, token:String, signature:Data) {
        self.signerPublicKey = signerPublicKey
        self.token = token
        self.signature = signature
    }
    
    init(json:Object) throws {
        try self.init(signerPublicKey: ((json ~> "signer_public_key") as String).fromBase64(),
                      token: json ~> "token",
                      signature: ((json ~> "signature") as String).fromBase64())
    }
    
    var object:Object {
        return ["signer_public_key": signerPublicKey.toBase64(),
                "token": token,
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
    let readerPublicKey:SodiumSignPublicKey
    let expiration:UInt64
    
    init(readerPublicKey:SodiumSignPublicKey, expiration:UInt64) {
        self.readerPublicKey = readerPublicKey
        self.expiration = expiration
    }
    
    init(json:Object) throws {
        try self.init(readerPublicKey: ((json ~> "reader_public_key") as String).fromBase64(),
                      expiration: json ~> "expiration")
    }
    
    var object:Object {
        return ["reader_public_key": readerPublicKey.toBase64(),
                "expiration": expiration]
    }
}

// Team Operation

struct TeamOperationResponse:Jsonable {
    let postedBlockHash:Data
    let data:TeamOperationResponseData?

    init(postedBlockHash:Data, data:TeamOperationResponseData? = nil) {
        self.postedBlockHash = postedBlockHash
        self.data = data
    }
    
    init(json:Object) throws {
        let data:TeamOperationResponseData? = try? TeamOperationResponseData(json: json ~> "data")
        try self.init(postedBlockHash: ((json ~> "posted_block_hash") as String).fromBase64(),
                      data: data)
    }
    
    var object:Object {
        var obj:Object = ["posted_block_hash": postedBlockHash.toBase64()]
        
        if let data = data {
            obj["data"] = data.object
        }
        
        return obj
    }
}


enum TeamOperationResponseData:Jsonable {
    typealias InviteLink = String

    enum Errors:Error {
        case unknownTeamOperationResponseData
    }
    
    case inviteLink(InviteLink)
    
    init(json: Object) throws {
        guard let link:InviteLink = try json ~> "invite_link" else {
            throw Errors.unknownTeamOperationResponseData
        }
        
        self = .inviteLink(link)
    }
    
    var object: Object {
        switch self {
        case .inviteLink(let link):
            return ["invite_link": link]
        }
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


