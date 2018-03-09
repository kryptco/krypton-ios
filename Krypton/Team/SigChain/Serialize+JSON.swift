//
//  SigChain+JSON.swift
//  Krypton
//
//  Created by Alex Grinman on 11/28/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import Sodium

/// Message
extension SigChain.SignedMessage:Jsonable {
    init(json: Object) throws {
        try self.init(publicKey: ((json ~> "public_key") as String).fromBase64(),
                      message: json ~> "message",
                      signature: ((json ~> "signature") as String).fromBase64())
    }
    
    var object: Object {
        return ["public_key": publicKey.toBase64(),
                "message": message,
                "signature": signature.toBase64()]
    }
}

extension SigChain.Message:Jsonable {
    init(json: Object) throws {
        try self.init(header: SigChain.Header(json: json ~> "header"),
                      body: SigChain.Body(json: json ~> "body"))
    }
    
    var object: Object {
        return ["header": header.object,
                "body": body.object]
    }

}

extension SigChain.Header:Jsonable {
    init(json: Object) throws {
        try self.init(utcTime: json ~> "utc_time",
                      protocolVersion: Version(string: json ~> "protocol_version"))
    }
    
    var object: Object {
        return ["utc_time": utcTime,
                "protocol_version": protocolVersion.string]
    }
}

extension SigChain.Body:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "main":
            self = try .main(SigChain.MainChain(json: jsonEnum.value()))
        case "log":
            self = try .log(SigChain.LogChain(json: jsonEnum.value()))
        case "read_token":
            self = try .readToken(SigChain.ReadToken(json: jsonEnum.value()))
        case "email_challenge":
            self = try .emailChallenge(SigChain.EmailChallenge(json: jsonEnum.value()))
        case "push_subscription":
            self = try .pushSubscription(SigChain.PushSubscription(json: jsonEnum.value()))
        case "read_billing_info":
            self = try .readBillingInfo(SigChain.ReadBillingInfo(json: jsonEnum.value()))
        default:
            throw SigChain.Errors.unknownMessageBodyType
        }
    }
    
    var object: Object {
        switch self {
        case .main(let mainChain):
            return ["main": mainChain.object]
        case .log(let logChain):
            return ["log": logChain.object]
        case .readToken(let readToken):
            return ["read_token": readToken.object]
        case .emailChallenge(let emailChallenge):
            return ["email_challenge": emailChallenge.object]
        case .pushSubscription(let pushSubscription):
            return ["push_subscription": pushSubscription.object]
        case .readBillingInfo(let readBilling):
            return ["read_billing_info": readBilling.object]
        }
    }
}


/// Genesis Block
extension SigChain.GenesisBlock:Jsonable {
    init(json: Object) throws {
        try self.init(creator: SigChain.Identity(json: json ~> "creator_identity"),
                      teamInfo: SigChain.TeamInfo(json: json ~> "team_info"))
        
    }
    
    var object: Object {
        return ["creator_identity": creator.object,
                "team_info": teamInfo.object]
        
    }
}

/// Block
extension SigChain.Block:Jsonable {
    init(json: Object) throws {
        try self.init(lastBlockHash: ((json ~> "last_block_hash") as String).fromBase64(),
                      operation: try SigChain.Operation(json: json ~> "operation"))
    }
    
    var object: Object {
        return ["last_block_hash": lastBlockHash.toBase64(),
                "operation": operation.object]
    }
    
}

extension SigChain.TeamInfo:Jsonable {
    init(json: Object) throws {
        try self.init(name: json ~> "name")
    }
    
    var object: Object {
        return ["name": name]
    }
}

extension SigChain.Policy:Jsonable {
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

extension SigChain.Identity:Jsonable {
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

extension SigChain.LoggingEndpoint:Jsonable {
    init(json: Object) throws {
        if let _:Object = try? json ~> "command_encrypted" {
            self = .commandEncrypted
        } else {
            throw SigChain.Errors.unknownLoggingEndpoint
        }
    }
    
    var object: Object {
        return ["command_encrypted": Object()]
    }
}

/// MainChain
extension SigChain.MainChain:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "read":
            self = try .read(SigChain.ReadBlocksRequest(json: jsonEnum.value()))
        case "create":
            self = try .create(SigChain.GenesisBlock(json: jsonEnum.value()))
        case "append":
            self = try .append(SigChain.Block(json: jsonEnum.value()))
        default:
            throw SigChain.Errors.badMainChainType
        }
    }
    
    var object: Object {
        switch self {
        case .create(let genesis):
            return ["create": genesis.object]
        case .read(let readRequest):
            return ["read": readRequest.object]
        case .append(let block):
            return ["append": block.object]
        }
    }
}

/// Operation
extension SigChain.Operation:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "invite":
            self = try .invite(SigChain.Invitation(json: jsonEnum.value()))
        case "close_invitations":
            self = .closeInvitations
        case "accept_invite":
            self = try .acceptInvite(SigChain.Identity(json: jsonEnum.value()))
        case "leave":
            self = .leave
            
        case "remove":
            self = try .remove((jsonEnum.value() as String).fromBase64())

        case "set_policy":
            self = try .setPolicy(SigChain.Policy(json: jsonEnum.value()))
            
        case "set_team_info":
            self = try .setTeamInfo(SigChain.TeamInfo(json: jsonEnum.value()))

        case "pin_host_key":
            self = try .pinHostKey(SSHHostKey(json: jsonEnum.value()))
        case "unpin_host_key":
            self = try .unpinHostKey(SSHHostKey(json: jsonEnum.value()))

        case "add_logging_endpoint":
            self = try .addLoggingEndpoint(SigChain.LoggingEndpoint(json: jsonEnum.value()))
        case "remove_logging_endpoint":
            self = try .removeLoggingEndpoint(SigChain.LoggingEndpoint(json: jsonEnum.value()))

        case "promote":
            self = try .promote((jsonEnum.value() as String).fromBase64())
        case "demote":
            self = try .demote((jsonEnum.value() as String).fromBase64())

        default:
            throw SigChain.Errors.badOperation
        }
    }
    
    var object: Object {
        switch self {
        case .invite(let invite):
            return ["invite": invite.object]
        case .closeInvitations:
            return ["close_invitations": [:]]
        case .acceptInvite(let accept):
            return ["accept_invite": accept.object]
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

extension SigChain.Invitation:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "direct":
            self = try .direct(SigChain.DirectInvitation(json: jsonEnum.value()))
        case "indirect":
            self = try .indirect(SigChain.IndirectInvitation(json: jsonEnum.value()))
        default:
            throw SigChain.Errors.badInvitationType
        }
    }
    
    var object: Object {
        switch self {
        case .direct(let direct):
            return ["direct": direct.object]
        case .indirect(let indirect):
            return ["indirect": indirect.object]
        }
    }
}

extension SigChain.DirectInvitation:Jsonable {
    init(json: Object) throws {
        publicKey = try ((json ~> "public_key") as String).fromBase64()
        email = try json ~> "email"
    }
    
    var object: Object {
        return ["public_key": publicKey.toBase64(), "email": email]
    }
}

extension SigChain.IndirectInvitation:Jsonable {
    init(json: Object) throws {
        try self.init(noncePublicKey: ((json ~> "nonce_public_key") as String).fromBase64(),
                      inviteSymmetricKeyHash: ((json ~> "invite_symmetric_key_hash") as String).fromBase64(),
                      inviteCiphertext: ((json ~> "invite_ciphertext") as String).fromBase64(),
                      restriction: Restriction(json: json ~> "restriction"))
    }
    
    var object: Object {
        return ["nonce_public_key": noncePublicKey.toBase64(),
                "invite_symmetric_key_hash": inviteSymmetricKeyHash.toBase64(),
                "invite_ciphertext": inviteCiphertext.toBase64(),
                "restriction": restriction.object]
    }
}

extension SigChain.IndirectInvitation.Restriction:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "domain":
            self = try .domain(jsonEnum.value())
        case "emails":
            self = try .emails(jsonEnum.value())
        default:
            throw SigChain.Errors.badIndirectInvitationRestriction
        }
    }
    
    var object: Object {
        switch self {
        case .domain(let domain):
            return ["domain": domain]
        case .emails(let emails):
            return ["emails": emails]
        }
    }
}

extension SigChain.IndirectInvitation.Secret:Jsonable {
    init(json: Object) throws {
        try self.init(initialTeamPublicKey: ((json ~> "initial_team_public_key") as String).fromBase64(),
                      lastBlockHash: ((json ~> "last_block_hash") as String).fromBase64(),
                      nonceKeypairSeed: ((json ~> "nonce_keypair_seed") as String).fromBase64(),
                      restriction: SigChain.IndirectInvitation.Restriction(json: json ~> "restriction"))
    }
    
    var object: Object {
        return ["initial_team_public_key": initialTeamPublicKey.toBase64(),
                "last_block_hash": lastBlockHash.toBase64(),
                "nonce_keypair_seed": nonceKeypairSeed.toBase64(),
                "restriction": restriction.object]
    }

}

/// SigChain+Read

extension SigChain.ReadBlocksRequest:Jsonable {
    init(json: Object) throws {
        let token = try? SigChain.SignedMessage(json: json ~> "token")
        
        try self.init(teamPointer: SigChain.TeamPointer(json: json ~> "team_pointer"),
                      nonce: ((json ~> "nonce") as String).fromBase64(),
                      token: token)
    }
    
    var object: Object {
        var obj:Object =  ["team_pointer": teamPointer.object,
                           "nonce": nonce.toBase64()]
        
        if let token = self.token {
            obj["token"] = token.object
        }
        
        return obj
    }
}

extension SigChain.ReadBlocksResponse:JsonReadable {
    init(json: Object) throws {
        try self.init(blocks: [SigChain.SignedMessage](json: json ~> "blocks"),
                      hasMore: json ~> "more")
    }
}

extension SigChain.TeamPointer:Jsonable {
    init(json:Object) throws {
        if let publicKey:String = try? json ~> "public_key" {
            self = try .publicKey(publicKey.fromBase64())
        }
        else if let blockHash:String = try? json ~> "last_block_hash" {
            self = try .lastBlockHash(blockHash.fromBase64())
        }
        else {
            throw SigChain.Errors.badTeamPointer
        }
    }
    
    var object: Object {
        switch self {
        case .publicKey(let pub):
            return ["public_key": pub.toBase64()]
        case .lastBlockHash(let hash):
            return ["last_block_hash": hash.toBase64()]
        }
    }
}

extension SigChain.ReadToken:Jsonable {
    init(json: Object) throws {
        self = try .time(SigChain.TimeToken(json: json ~> "time"))
    }
    
    var object: Object {
        switch self {
        case .time(let timeToken):
            return ["time": timeToken.object]
        }
    }
}

extension SigChain.TimeToken:Jsonable {
    init(json:Object) throws {
        try self.init(readerPublicKey: ((json ~> "reader_public_key") as String).fromBase64(),
                      expiration: json ~> "expiration")
    }
    
    var object:Object {
        return ["reader_public_key": readerPublicKey.toBase64(),
                "expiration": expiration]
    }
}

/// LogChain
extension SigChain.LogChain:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "create":
            self = try .create(SigChain.GenesisLogBlock(json: jsonEnum.value()))
        case "append":
            self = try .append(SigChain.LogBlock(json: jsonEnum.value()))
        case "read":
            self = try .read(SigChain.ReadLogBlocksRequest(json: jsonEnum.value()))
        default:
            throw SigChain.Errors.badLogChainType
        }
    }
    
    var object: Object {
        switch self {
        case .create(let genesis):
            return ["create": genesis.object]
        case .append(let block):
            return ["append": block.object]
        case .read(let read):
            return ["read": read.object]
        }
    }
}

extension SigChain.LogBlock:Jsonable {
    init(json: Object) throws {
        try self.init(lastBlockHash: ((json ~> "last_block_hash") as String).fromBase64(),
                      operation: SigChain.LogOperation(json: json ~> "operation"))
    }
    
    var object: Object {
        return ["last_block_hash": lastBlockHash.toBase64(),
                "operation": operation.object]
    }
}

extension SigChain.GenesisLogBlock:Jsonable {
    init(json: Object) throws {
        try self.init(teamPointer: SigChain.TeamPointer(json: json ~> "team_pointer"),
                      wrappedKeys: [SigChain.WrappedKey](json: json ~> "wrapped_keys"))
    }
    
    var object: Object {
        return ["team_pointer": teamPointer.object,
                "wrapped_keys": wrappedKeys.objects]
    }
    
}

extension SigChain.LogOperation:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "add_wrapped_keys":
            self = try .addWrappedKeys([SigChain.WrappedKey](json: jsonEnum.value()))
        case "rotate_key":
            self = try .rotateKey([SigChain.WrappedKey](json: jsonEnum.value()))
        case "encrypt_log":
            self = try .encryptLog(SigChain.EncryptedLog(json: jsonEnum.value()))
        default:
            throw SigChain.Errors.badLogOperation
        }
    }
    
    var object: Object {
        switch self {
        case .addWrappedKeys(let wrappedKeys):
            return ["add_wrapped_keys": wrappedKeys.objects]
        case .rotateKey(let wrappedKeys):
            return ["rotate_key": wrappedKeys.objects]
        case .encryptLog(let log):
            return ["encrypt_log": log.object]
        }
    }
}

extension SigChain.EncryptedLog:Jsonable {
    init(json: Object) throws {
        ciphertext = try ((json ~> "ciphertext") as String).fromBase64()
    }
    
    var object: Object {
        return ["ciphertext": ciphertext.toBase64()]
    }
}

extension SigChain.ReadLogBlocksRequest: Jsonable {
    init(json: Object) throws {
        nonce = try ((json ~> "nonce") as String).fromBase64()
        filter = try SigChain.LogsFilter(json: json ~> "filter")
    }
    var object: Object {
        return ["nonce": nonce.toBase64(),
                "filter": filter.object]
    }
}


extension SigChain.ReadLogBlocksResponse: Jsonable {
    init(json: Object) throws {
        logBlocks = try [SigChain.SignedMessage](json: json ~> "blocks")
        more = try json ~> "more"
    }
    
    var object: Object {
        return ["blocks": logBlocks.objects,
                "more": more]
    }
}

extension SigChain.LogsFilter: Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "member":
            self = try .member(SigChain.LogChainPointer(json: jsonEnum.value()))
            
        default:
            throw SigChain.Errors.badReadLogsRequest
        }
    }
    
    var object: Object {
        switch self {
        case .member(let pointer):
            return ["member": pointer.object]
        }
    }
}

extension SigChain.LogChainPointer: Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "genesis_block":
            self = try .genesisBlock(SigChain.LogChainGenesisPointer(json: jsonEnum.value()))
        case "last_block_hash":
            self = try .lastBlockHash((jsonEnum.value() as String).fromBase64())

        default:
            throw SigChain.Errors.badReadLogsRequest
        }
    }
    
    var object: Object {
        switch self {
        case .genesisBlock(let pointer):
            return ["genesis_block": pointer.object]
        case .lastBlockHash(let hash):
            return ["last_block_hash": hash.toBase64()]
        }
    }
}

extension SigChain.LogChainGenesisPointer: Jsonable {
    init(json: Object) throws {
        teamPublicKey = try ((json ~> "team_public_key") as String).fromBase64()
        memberPublicKey = try ((json ~> "member_public_key") as String).fromBase64()
    }
    
    var object: Object {
        return ["team_public_key": teamPublicKey.toBase64(),
                "member_public_key": memberPublicKey.toBase64()]
    }
}

// Boxed Message
extension SigChain.WrappedKey:Jsonable {
    init(json: Object) throws {
        recipientPublicKey  = try ((json ~> "recipient_public_key") as String).fromBase64()
        ciphertext          = try ((json ~> "ciphertext") as String).fromBase64()
    }
    
    var object: Object {
        return ["recipient_public_key": recipientPublicKey.toBase64(),
                "ciphertext": ciphertext.toBase64()]
    }
}

extension SigChain.BoxedMessage:Jsonable {
    init(json: Object) throws {
        recipientPublicKey  = try ((json ~> "recipient_public_key") as String).fromBase64()
        senderPublicKey     = try ((json ~> "sender_public_key") as String).fromBase64()
        ciphertext          = try ((json ~> "ciphertext") as String).fromBase64()
    }
    
    var object: Object {
        return ["recipient_public_key": recipientPublicKey.toBase64(),
                "sender_public_key": senderPublicKey.toBase64(),
                "ciphertext": ciphertext.toBase64()]
    }
}

extension SigChain.PlaintextBody:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "log_encryption_key":
            self = try .logEncryptionKey((jsonEnum.value() as String).fromBase64())
        default:
            throw SigChain.Errors.badPlaintextBody
        }
    }
    
    var object: Object {
        switch self {
        case .logEncryptionKey(let symmetricKey):
            return ["log_encryption_key": symmetricKey.toBase64()]
        }

    }
}

/// Email Challenge
extension SigChain.EmailChallenge:Jsonable {
    init(json: Object) throws {
        try self.init(nonce: ((json ~> "nonce") as String).fromBase64())
    }
    
    var object: Object {
        return ["nonce": nonce.toBase64()]
    }
}

/// PushSubscription
extension SigChain.PushSubscription:Jsonable {
    init(json: Object) throws {
        try self.init(teamPointer: SigChain.TeamPointer(json: json ~> "team_pointer"),
                  action: SigChain.PushSubscriptionAction(json: json ~> "action"))
    }
    
    var object: Object {
        return ["team_pointer": teamPointer.object,
                "action": action.object]
    }
}
extension SigChain.PushSubscriptionAction:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "subscribe":
            self = try .subscribe(SigChain.PushDevice(json: jsonEnum.value()))
        case "unsubscribe":
            self = .unsubscribe
        default:
            throw SigChain.Errors.badPushSubscriptionType
        }
    }
    
    var object: Object {
        switch self {
        case .subscribe(let device):
            return ["subscribe": device.object]
        case .unsubscribe:
            return ["unsubscribe": [:]]
        }
    }

}

extension SigChain.PushDevice:Jsonable {
    init(json: Object) throws {
        let jsonEnum = try JSONEnum(json: json)
        
        switch jsonEnum.type {
        case "ios":
            self = try .iOS(jsonEnum.value())
        case "android":
            self = try .android(jsonEnum.value())
        case "queue":
            self = try .queue(jsonEnum.value())
        default:
            throw SigChain.Errors.badLogOperation
        }
    }
    
    var object: Object {
        switch self {
        case .iOS(let token):
            return ["ios": token]
        case .android(let token):
            return ["android": token]
        case .queue(let arn):
            return ["queue": arn]
        }
    }

}

// MARK: Read Billing

extension SigChain.ReadBillingInfo:Jsonable {
    init(json: Object) throws {
        let token:Object? = try? json ~> "token"
        try self.init(teamPublicKey: ((json ~> "team_public_key") as String).fromBase64(),
                      token: token.map { try SigChain.SignedMessage(json: $0) })
    }
    
    var object: Object {
        var object:Object = ["team_public_key": teamPublicKey.toBase64()]
        
        if let token = self.token {
            object["token"] = token.object
        }
        
        return object
    }
}

