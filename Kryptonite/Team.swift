//
//  Team.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct Team:Jsonable {

    /// The team's information
    struct Info:Jsonable {
        let name:String
        
        init(name:String) {
            self.name = name
        }
        
        init(json: Object) throws {
            try self.init(name: json ~> "name")
        }
        
        var object: Object {
            return ["name": name]
        }
    }

    
    /// the team's policy settings
    struct PolicySettings:Jsonable {
        let temporaryApprovalSeconds:UInt64?
                
        init(temporaryApprovalSeconds:UInt64?) {
            self.temporaryApprovalSeconds = temporaryApprovalSeconds
        }
        
        init(json: Object) throws {
            self.init(temporaryApprovalSeconds: try? json ~> "temporary_approval_seconds")
        }
        
        var object: Object {
            if let seconds = temporaryApprovalSeconds {
                return ["temporary_approval_seconds": seconds]
            }
            
            return [:]
        }
    }
    
    struct MemberIdentity:Jsonable {
        let publicKey:SodiumPublicKey
        let email:String
        let sshPublicKey:Data
        let pgpPublicKey:Data
        
        init(publicKey:SodiumPublicKey, email:String, sshPublicKey:Data, pgpPublicKey:Data) {
            self.publicKey = publicKey
            self.email = email
            self.sshPublicKey = sshPublicKey
            self.pgpPublicKey = pgpPublicKey
        }
        
        init(json: Object) throws {
            try self.init(publicKey: SodiumPublicKey(((json ~> "public_key") as String).fromBase64()),
                          email: json ~> "email",
                          sshPublicKey: ((json ~> "ssh_public_key") as String).fromBase64(),
                          pgpPublicKey: ((json ~> "pgp_public_key") as String).fromBase64())
            
        }
        
        var object: Object {
            return ["public_key": publicKey.toBase64(),
                    "email": email,
                    "ssh_public_key": sshPublicKey.toBase64(),
                    "pgp_public_key": pgpPublicKey.toBase64()]
        }
    }
    
    var info:Info
    var policy:PolicySettings
    var lastBlockHash:Data?
    var lastInvitePublicKey:SodiumPublicKey?
        
    var name:String {
        return info.name
    }
    

    init(info:Info, policy:PolicySettings = PolicySettings(temporaryApprovalSeconds: nil), lastBlockHash:Data? = nil,
         lastInvitePublicKey:SodiumPublicKey? = nil)
    {
        self.info = info
        self.policy = policy
        self.lastBlockHash = lastBlockHash
        self.lastInvitePublicKey = lastInvitePublicKey
    }
    
    init(json: Object) throws {
        let lastBlockHash:String? = try? json ~> "last_block_hash"
        let lastInvitePublicKey:String? = try? json ~> "last_invite_public_key"

        try self.init(info: Info(json: json ~> "info"),
                      policy: PolicySettings(json: json ~> "policy"),
                      lastBlockHash: lastBlockHash?.fromBase64(),
                      lastInvitePublicKey: lastInvitePublicKey?.fromBase64())
    }
    
    var object: Object {
        var obj:Object = ["info": info.object,                        
                          "policy": policy.object]
        
        if let blockHash = lastBlockHash {
            obj["last_block_hash"] = blockHash.toBase64()
        }
        
        if let invitePublicKey = lastInvitePublicKey {
            obj["last_invite_public_key"] = invitePublicKey.toBase64()
        }
        
        return obj
    }
    

}
