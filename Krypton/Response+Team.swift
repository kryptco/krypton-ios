//
//  Response+Team.swift
//  Krypton
//
//  Created by Alex Grinman on 10/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import Sodium

struct TeamCheckpoint {
    let publicKey:SodiumSignPublicKey
    let teamPublicKey:SodiumSignPublicKey
    let lastBlockHash:Data
    let serverEndpoints:ServerEndpoints
}

extension TeamCheckpoint:Jsonable {
    init(json:Object) throws {
        try self.init(publicKey: ((json ~> "public_key") as String).fromBase64(),
                      teamPublicKey: ((json ~> "team_public_key") as String).fromBase64(),
                      lastBlockHash: ((json ~> "last_block_hash") as String).fromBase64(),
                      serverEndpoints: ServerEndpoints(json: json ~> "server_endpoints"))
    }
    
    var object:Object {
        return ["public_key": publicKey.toBase64(),
                "team_public_key": teamPublicKey.toBase64(),
                "last_block_hash": lastBlockHash.toBase64(),
                "server_endpoints": serverEndpoints.object]
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

extension TeamOperationResponseData {
    // helper function to get an invite link out
    var inviteLink:InviteLink? {
        guard case .inviteLink(let link) = self
        else {
            return nil
        }
        
        return link
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


