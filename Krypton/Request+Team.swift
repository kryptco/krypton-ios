//
//  Request+Team.swift
//  Krypton
//
//  Created by Alex Grinman on 10/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct CreateTeamRequest:Jsonable {
    let teamInfo:SigChain.TeamInfo
    
    init(json: Object) throws {
        teamInfo = try SigChain.TeamInfo(json: json ~> "team_info")
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
    case directInvite(SigChain.DirectInvitation)
    case indirectInvite(SigChain.IndirectInvitation.Restriction)
    case leave
    case closeInvitations
    
    case remove(SodiumSignPublicKey)
    case promote(SodiumSignPublicKey)
    case demote(SodiumSignPublicKey)

    case setPolicy(SigChain.Policy)
    case setTeamInfo(SigChain.TeamInfo)
    
    case pinHostKey(SSHHostKey)
    case unpinHostKey(SSHHostKey)
    
    case addLoggingEndpoint(SigChain.LoggingEndpoint)
    case removeLoggingEndpoint(SigChain.LoggingEndpoint)
    
    
    enum Errors:Error {
        case badRequestableOperation
    }
    
    init(json: Object) throws {
        if let invite:Object = try? json ~> "indirect_invite" {
            self = try .indirectInvite(SigChain.IndirectInvitation.Restriction(json: invite))
        }
        else if let invite:Object = try? json ~> "direct_invite" {
            self = try .directInvite(SigChain.DirectInvitation(json: invite))
        }
        else if let _:Object = try? json ~> "close_invitations" {
            self = .closeInvitations
        }
        else if let _:Object = try? json ~> "leave" {
            self = .leave
        }
        else if let remove:String = try? json ~> "remove" {
            self = try .remove(remove.fromBase64())
        }
        else if let policy:Object = try? json ~> "set_policy" {
            self = try .setPolicy(SigChain.Policy(json: policy))
        }
        else if let info:Object = try? json ~> "set_team_info" {
            self = try .setTeamInfo(SigChain.TeamInfo(json: info))
        }
        else if let host:Object = try? json ~> "pin_host_key" {
            self = try .pinHostKey(SSHHostKey(json: host))
        }
        else if let host:Object = try? json ~> "unpin_host_key" {
            self = try .unpinHostKey(SSHHostKey(json: host))
        }
        else if let endpoint:Object = try? json ~> "add_logging_endpoint" {
            self = try .addLoggingEndpoint(SigChain.LoggingEndpoint(json: endpoint))
        }
        else if let endpoint:Object = try? json ~> "remove_logging_endpoint" {
            self = try .removeLoggingEndpoint(SigChain.LoggingEndpoint(json: endpoint))
        }
        else if let publicKeyString:String = try? json ~> "promote" {
            self = try .promote(publicKeyString.fromBase64())
        }
        else if let publicKeyString:String = try? json ~> "demote" {
            self = try .demote(publicKeyString.fromBase64())
        }
        else {
            throw Errors.badRequestableOperation
        }
    }
    
    var object: Object {
        switch self {
        case .directInvite(let invite):
            return ["direct_invite": invite.object]
        case .indirectInvite(let restriction):
            return ["indirect_invite": restriction.object]
        case .closeInvitations:
            return ["close_invitations": [:]]
        case .leave:
            return ["leave": [:]]
        case .remove(let remove):
            return ["remove": remove.toBase64()]
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
        case .promote(let admin):
            return ["promote": admin.toBase64()]
        case .demote(let admin):
            return ["demote": admin.toBase64()]
        }
    }
}

struct LogDecryptionRequest:Jsonable {
    let wrappedKey: SigChain.BoxedMessage
    
    init(json: Object) throws {
        wrappedKey = try SigChain.BoxedMessage(json: json ~> "wrapped_key")
    }
    var object: Object {
        return ["wrapped_key": wrappedKey.object]
    }
}
