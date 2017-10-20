//
//  SigChain+Construct.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import Sodium

enum TeamChainBlockCreateError:Error {
    case noBlockHash
    case noActiveInvitation
    case noSuchMemberToRemove
    case noSuchAdmin
    case seedToKeyPair
    case sig
}


enum SigChainLink {
    case invite(teamPublicKey:SodiumSignPublicKey, blockHash:Data, noncePrivateKey:SodiumSignSecretKey)
    
    static let scheme = "kr://"
    
    enum Path:String {
        case invite = "join_team"
    }
    
    var string:String {
        switch self {
        case .invite(let teamPublicKey, let blockHash, let noncePrivateKey):
            let path = Path.invite.rawValue
            return "\(SigChainLink.scheme)\(path)/\(teamPublicKey.toBase64())/\(blockHash.toBase64())/\(noncePrivateKey.toBase64())"
        }
    }
}

extension TeamIdentity {
    
    /**
     Creates a signed SigChain request append block for a given append operation
     
     - returns: `SigChain.Request` that can be posted to the team server
     - parameters:
         - operation: the operation to append to the team sig chain
     */

    private func signedAppendBlock(for operation:SigChain.Operation) throws -> SigChain.Request {
        guard let blockHash = try self.dataManager.lastBlockHash() else {
            throw TeamChainBlockCreateError.noBlockHash
        }
        
        let appendBlock = SigChain.AppendBlock(lastBlockHash: blockHash,
                                               operation: operation)
        
        let payload = SigChain.Payload.appendBlock(appendBlock)
        let payloadData = try payload.jsonData()
        
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: self.keyPair.secretKey) else {
            throw TeamChainBlockCreateError.sig
        }
        
        let payloadString = try payloadData.utf8String()
        return SigChain.Request(publicKey: self.keyPair.publicKey, payload: payloadString, signature: signature)
    }
    
    /**
     Create a new `Membership Invitation` Block
     
     - returns:
         - `inviteURL` string that can be used by clients to join the team
         - `SigChain.Request` that can be posted to the team server
 
     */
    func invitationBlock() throws -> (inviteURL:String, request:SigChain.Request){
        
        // create an invitation nonce keypair
        let nonceSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        guard let nonceKeyPair = KRSodium.instance().sign.keyPair(seed: nonceSeed) else {
            throw TeamChainBlockCreateError.seedToKeyPair
        }
        
        let invitationOperation = SigChain.Operation.inviteMember(SigChain.MemberInvitation(noncePublicKey: nonceKeyPair.publicKey))
        let request = try signedAppendBlock(for: invitationOperation)
        
        let newBlockHash = request.block.hash()
        
        // create the url link
        let inviteLink = SigChainLink.invite(teamPublicKey: initialTeamPublicKey,
                                             blockHash: newBlockHash,
                                             noncePrivateKey: nonceKeyPair.secretKey).string
        
        return (inviteLink, request)
    }
    
    /**
     Create a new `Cancel Invitation` Block
     
     - returns:
         `SigChain.Request` that can be posted to the team server
     */
    func cancelInvitationBlock() throws -> SigChain.Request {
        guard let lastInvitePublicKey = try self.team().lastInvitePublicKey else {
            throw TeamChainBlockCreateError.noActiveInvitation
        }
        
        let cancelInviteOperation = SigChain.Operation.cancelInvite(SigChain.MemberInvitation(noncePublicKey: lastInvitePublicKey))
        return try signedAppendBlock(for: cancelInviteOperation)
    }
    
    /**
     Create a new `Remove Member` Block
     
     - returns:
         `SigChain.Request` that can be posted to the team server
     
     - parameters:
         - memberPublicKey: the sign public key of the member to remove from the team

     */
    func removeMemberBlock(for memberPublicKey:SodiumSignPublicKey) throws -> SigChain.Request {
        guard let _ = try self.dataManager.fetchMemberIdentity(for: memberPublicKey) else {
            throw TeamChainBlockCreateError.noSuchMemberToRemove
        }
        
        let operation = SigChain.Operation.removeMember(memberPublicKey)
        return try signedAppendBlock(for: operation)
    }
    
    
    /**
     Create a new `Set Policy` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - policySettings: the policy settings to create
     
     */
    func setPolicyBlock(for policySettings:Team.PolicySettings) throws -> SigChain.Request {
        let operation = SigChain.Operation.setPolicy(policySettings)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Set Policy` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
         - teamInfo: the team info to create
     
     */
    func setTeamInfoBlock(for teamInfo:Team.Info) throws -> SigChain.Request {
        let operation = SigChain.Operation.setTeamInfo(teamInfo)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Pin Host Key` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - hostKey: the host and key to pin for the team
     
     */
    func pinHostKeyBlock(for hostKey:SSHHostKey) throws -> SigChain.Request {
        let operation = SigChain.Operation.pinHostKey(hostKey)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Unpin Host Key` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - hostKey: the host and key to **unpin** for the team
     
     */
    func unpinHostKeyBlock(for hostKey:SSHHostKey) throws -> SigChain.Request {
        let operation = SigChain.Operation.unpinHostKey(hostKey)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Add Logging Endpoint` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - endpoint: the logging endpoint to add
     
     */
    func addLoggingEndpoingBlock(for endpoint:Team.LoggingEndpoint) throws -> SigChain.Request {
        let operation = SigChain.Operation.addLoggingEndpoint(endpoint)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Remove Logging Endpoint` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - endpoint: the logging endpoint to add
     
     */
    func removeLoggingEndpoingBlock(for endpoint:Team.LoggingEndpoint) throws -> SigChain.Request {
        let operation = SigChain.Operation.removeLoggingEndpoint(endpoint)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Add Admin` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - memberPublicKey: the public key of member to promote
     
     */
    func addAdminBlock(for memberPublicKey:SodiumSignPublicKey) throws -> SigChain.Request {
        guard let _ = try self.dataManager.fetchMemberIdentity(for: memberPublicKey) else {
            throw TeamChainBlockCreateError.noSuchMemberToRemove
        }

        let operation = SigChain.Operation.addAdmin(memberPublicKey)
        return try signedAppendBlock(for: operation)
    }
    
    /**
     Create a new `Remove Admin` Block
     
     - returns:
     `SigChain.Request` that can be posted to the team server
     
     - parameters:
     - memberPublicKey: the public key of member to demote
     */
    func removeAdminBlock(for adminPublicKey:SodiumSignPublicKey) throws -> SigChain.Request {
        guard try self.dataManager.isAdmin(for: adminPublicKey) else {
            throw TeamChainBlockCreateError.noSuchAdmin
        }
        
        let operation = SigChain.Operation.removeAdmin(adminPublicKey)
        return try signedAppendBlock(for: operation)
    }
}
