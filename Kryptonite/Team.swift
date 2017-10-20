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
        
        var description:String {
            if let approvalSeconds = temporaryApprovalSeconds {
                return TimeInterval(approvalSeconds).timeAgo(suffix: "")
            } else {
                return "unset"
            }
        }
    }
    
    struct MemberIdentity:Jsonable {
        let publicKey:SodiumSignPublicKey
        let encryptionPublicKey:SodiumSignPublicKey
        let email:String
        let sshPublicKey:Data
        let pgpPublicKey:Data
        
        init(publicKey:SodiumSignPublicKey, encryptionPublicKey:SodiumSignPublicKey, email:String, sshPublicKey:Data, pgpPublicKey:Data) {
            self.publicKey = publicKey
            self.encryptionPublicKey = encryptionPublicKey
            self.email = email
            self.sshPublicKey = sshPublicKey
            self.pgpPublicKey = pgpPublicKey
        }
        
        init(json: Object) throws {
            try self.init(publicKey: SodiumSignPublicKey(((json ~> "public_key") as String).fromBase64()),
                          encryptionPublicKey: SodiumSignPublicKey(((json ~> "encryption_public_key") as String).fromBase64()),
                          email: json ~> "email",
                          sshPublicKey: ((json ~> "ssh_public_key") as String).fromBase64(),
                          pgpPublicKey: ((json ~> "pgp_public_key") as String).fromBase64())
            
        }
        
        var object: Object {
            return ["public_key": publicKey.toBase64(),
                    "encryption_public_key": encryptionPublicKey.toBase64(),
                    "email": email,
                    "ssh_public_key": sshPublicKey.toBase64(),
                    "pgp_public_key": pgpPublicKey.toBase64()]
        }
    }
    
    enum LoggingEndpoint:Jsonable,Equatable {
        case commandEncrypted
        
        var displayDescription:String {
            switch self {
            case .commandEncrypted:
                return "Krypt.co Encrypted"
            }
        }
        struct UnknownEndpoint:Error {}
        
        init(json: Object) throws {
            if let _:Object = try? json ~> "command_encrypted" {
                self = .commandEncrypted
            } else {
                throw UnknownEndpoint()
            }
        }
        
        var object: Object {
            return ["command_encrypted": Object()]
        }
        
        static func ==(l:LoggingEndpoint, r:LoggingEndpoint) -> Bool {
            switch (l, r) {
            case (.commandEncrypted, .commandEncrypted):
                return true
            }
        }
    }
    
    
    var info:Info
    var policy:PolicySettings
    var lastInvitePublicKey:SodiumSignPublicKey?
    var loggingEndpoints:[LoggingEndpoint] = []
    
    var name:String {
        return info.name
    }
    
    var commandEncryptedLoggingEnabled:Bool {
        return loggingEndpoints.index(of: LoggingEndpoint.commandEncrypted) != nil
    }

    init(info:Info, policy:PolicySettings = PolicySettings(temporaryApprovalSeconds: nil),
         lastInvitePublicKey:SodiumSignPublicKey? = nil, loggingEndpoints:[LoggingEndpoint] = [])
    {
        self.info = info
        self.policy = policy
        self.lastInvitePublicKey = lastInvitePublicKey
        self.loggingEndpoints = loggingEndpoints
    }
    
    init(json: Object) throws {
        let lastInvitePublicKey:String? = try? json ~> "last_invite_public_key"

        try self.init(info: Info(json: json ~> "info"),
                      policy: PolicySettings(json: json ~> "policy"),
                      lastInvitePublicKey: lastInvitePublicKey?.fromBase64(),
                      loggingEndpoints: [LoggingEndpoint](json: json ~> "logging_endpoints"))
    }
    
    var object: Object {
        var obj:Object = ["info": info.object,                        
                          "policy": policy.object,
                          "logging_endpoints": loggingEndpoints.objects]
        
        if let invitePublicKey = lastInvitePublicKey {
            obj["last_invite_public_key"] = invitePublicKey.toBase64()
        }
        
        return obj
    }
    

}
