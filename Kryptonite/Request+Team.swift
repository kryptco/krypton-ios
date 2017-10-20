//
//  Request+Team.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct CreateTeamRequest:Jsonable {
    let teamInfo:Team.Info
    
    init(json: Object) throws {
        teamInfo = try Team.Info(json: json ~> "team_info")
    }
    
    var object: Object {
        return ["team_info": teamInfo.object]
    }
}

struct ReadTeamRequest:Jsonable {
    let publicKey:SodiumSignPublicKey

    init(json: Object) throws {
        publicKey = try ((json ~> "public_key") as String).fromBase64()
    }
    
    var object: Object {
        return ["public_key": publicKey.toBase64()]
    }
}

struct TeamOperationRequest:Jsonable {
    let operation: RequestableTeamOperation
    
    init(json: Object) throws {
        operation = try RequestableTeamOperation(json: json ~> "operation")
    }
    
    var object: Object {
        return ["operation": operation.object]
    }
}


// similar to Operation from `team_chain.md`
enum RequestableTeamOperation:Jsonable {
    case invite
    case cancelInvite
    
    case removeMember(SodiumSignPublicKey)
    
    case setPolicy(Team.PolicySettings)
    case setTeamInfo(Team.Info)
    
    case pinHostKey(SSHHostKey)
    case unpinHostKey(SSHHostKey)
    
    case addLoggingEndpoint(Team.LoggingEndpoint)
    case removeLoggingEndpoint(Team.LoggingEndpoint)
    
    case addAdmin(SodiumSignPublicKey)
    case removeAdmin(SodiumSignPublicKey)
    
    enum Errors:Error {
        case badRequestableOperation
    }
    
    init(json: Object) throws {
        if let _:Object = try? json ~> "invite" {
            self = .invite
        }
        else if let _:Object = try? json ~> "cancel_invite" {
            self = .cancelInvite
        }
        else if let remove:String = try? json ~> "remove_member" {
            self = try .removeMember(remove.fromBase64())
        }
        else if let policy:Object = try? json ~> "set_policy" {
            self = try .setPolicy(Team.PolicySettings(json: policy))
        }
        else if let info:Object = try? json ~> "set_team_info" {
            self = try .setTeamInfo(Team.Info(json: info))
        }
        else if let host:Object = try? json ~> "pin_host_key" {
            self = try .pinHostKey(SSHHostKey(json: host))
        }
        else if let host:Object = try? json ~> "unpin_host_key" {
            self = try .unpinHostKey(SSHHostKey(json: host))
        }
        else if let endpoint:Object = try? json ~> "add_logging_endpoint" {
            self = try .addLoggingEndpoint(Team.LoggingEndpoint(json: endpoint))
        }
        else if let endpoint:Object = try? json ~> "remove_logging_endpoint" {
            self = try .removeLoggingEndpoint(Team.LoggingEndpoint(json: endpoint))
        }
        else if let publicKeyString:String = try? json ~> "add_admin" {
            self = try .addAdmin(publicKeyString.fromBase64())
        }
        else if let publicKeyString:String = try? json ~> "remove_admin" {
            self = try .removeAdmin(publicKeyString.fromBase64())
        }
        else {
            throw Errors.badRequestableOperation
        }
    }
    
    var object: Object {
        switch self {
        case .invite:
            return ["invite": [:]]
        case .cancelInvite:
            return ["cancel_invite": [:]]
        case .removeMember(let remove):
            return ["remove_member": remove.toBase64()]
        case .setPolicy(let policy):
            return ["set_policy": policy.object]
        case .setTeamInfo(let info):
            return ["set_team_info": info.object]
        case .pinHostKey(let host):
            return ["pin_host_key": host.object]
        case .unpinHostKey(let host):
            return ["unpin_host_key": host.object]
        case .addLoggingEndpoint(let endpoint):
            return ["add_logging_endpoint": endpoint.object]
        case .removeLoggingEndpoint(let endpoint):
            return ["remove_logging_endpoint": endpoint.object]
        case .addAdmin(let admin):
            return ["add_admin": admin.toBase64()]
        case .removeAdmin(let admin):
            return ["remove_admin": admin.toBase64()]
        }
    }
}

struct LogDecryptionRequest:Jsonable {
    let wrappedKey: SigChain.WrappedKey
    
    init(json: Object) throws {
        wrappedKey = try SigChain.WrappedKey(json: json ~> "wrapped_key")
    }
    var object: Object {
        return ["wrapped_key": wrappedKey.object]
    }
}
