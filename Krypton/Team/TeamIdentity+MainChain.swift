//
//  SigChain+Construct.swift
//  Krypton
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
    case noSuchMember
    case noSuchAdmin
    case noSuchPinnedHostKey
    case noSuchLoggingEndpoint
    case seedToKeyPair
    case signing
}

extension TeamIdentity {
    
    
    /**
     Creates a  `SignedMessage` for a main chain append operation
     
     - returns: `SigChain.SignedMessage` that can be posted to the team server
     - parameters:
     - operation: the operation to append to the team sig chain
     */
    func sign(operation:SigChain.Operation, lastBlockHash: Data) throws -> SigChain.SignedMessage {        
        let block = SigChain.Block(lastBlockHash: lastBlockHash, operation: operation)
        return try self.sign(body: .main(.append(block)))
    }
    
    /**
     Creates a  `SignedMessage` for a message body
     
     - returns: `SigChain.SignedMessage`
     - parameters:
     - body: the message body to sign
     */
    func sign(body:SigChain.Body) throws -> SigChain.SignedMessage {
        return try self.sign(message: SigChain.Message(body: body))
    }
    
    /**
        Create a signed message for a `Requestable Operation`
        **Note**: Mutates teamIdentity state
     
        - returns:
        - `SigChain.SignedMessage` the signed message to post the block to the main chain
        - `TeamOperationResponseData` relevant esponse data for the callee
     */
    func signedMessage(for requestableOperation:RequestableTeamOperation, dataManager: TeamDataManager) throws -> (SigChain.SignedMessage, TeamOperationResponseData?) {

        guard let lastBlockHash = try dataManager.lastBlockHash() else {
            throw TeamChainBlockCreateError.noBlockHash
        }

        var operation:SigChain.Operation
        var responseData:TeamOperationResponseData?
        
        switch requestableOperation {
        case .directInvite(let direct):
            operation = .invite(.direct(direct))

        case .indirectInvite(let restriction):
            var invite:SigChain.JoinTeamInvite
            (invite, operation) = try indirectInvitationBlock(for: restriction, lastBlockHash: lastBlockHash)
            responseData = .inviteLink(SigChain.Link.invite(invite).string(for: Constants.appURLScheme))
                        
        case .closeInvitations:
            operation = .closeInvitations
            
        case .leave:
            operation = .leave

        case .remove(let memberPublicKey):
            guard let _ = try dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                throw TeamChainBlockCreateError.noSuchMember
            }
            
            operation = .remove(memberPublicKey)
            
        case .setPolicy(let policy):
            operation = .setPolicy(policy)
            
        case .setTeamInfo(let info):
            operation = .setTeamInfo(info)
            
        case .pinHostKey(let hostKey):
            operation = .pinHostKey(hostKey)
            
        case .unpinHostKey(let hostKey):
            guard try dataManager.isPinned(hostKey: hostKey) else {
                throw TeamChainBlockCreateError.noSuchPinnedHostKey
            }
            
            operation = .unpinHostKey(hostKey)
            
        case .addLoggingEndpoint(let endpoint):
            operation = .addLoggingEndpoint(endpoint)
            
        case .removeLoggingEndpoint(let endpoint):
            guard try dataManager.fetchTeam().loggingEndpoints.contains(endpoint) else {
                throw TeamChainBlockCreateError.noSuchLoggingEndpoint
            }
            
            operation = .removeLoggingEndpoint(endpoint)
            
        case .promote(let memberPublicKey):
            guard let _ = try dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                throw TeamChainBlockCreateError.noSuchMember
            }
            
            operation = .promote(memberPublicKey)
            
        case .demote(let adminPublicKey):
            guard try dataManager.isAdmin(for: adminPublicKey) else {
                throw TeamChainBlockCreateError.noSuchAdmin
            }

            operation = .demote(adminPublicKey)

        }
        
        let signedMessage = try self.sign(operation: operation, lastBlockHash: lastBlockHash)
        return (signedMessage, responseData)
    }
    
    /**
     Create a new `Invitation` Block for an indirect invitation restriction
     
     - returns:
         - `invite` TeamInvite that can be used by clients to join the team
         - `SigChain.SignedMessage` that can be posted to the team server
 
     */
    func indirectInvitationBlock(for restriction:SigChain.IndirectInvitation.Restriction, lastBlockHash: Data) throws -> (invite:SigChain.JoinTeamInvite, operation:SigChain.Operation){
    
        // create an invitation nonce keypair
        let nonceKeyPairSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        guard let nonceKeyPair = KRSodium.instance().sign.keyPair(seed: nonceKeyPairSeed) else {
            throw TeamChainBlockCreateError.seedToKeyPair
        }
        
        // create the invite
        let invite = SigChain.IndirectInvitation.Secret(initialTeamPublicKey: initialTeamPublicKey,
                                     lastBlockHash: lastBlockHash,
                                     nonceKeypairSeed: nonceKeyPairSeed,
                                     restriction: restriction)
        
        let inviteJson = try invite.jsonData()

        // create a secret box symmetric key
        let symmetricKey = try Data.random(size: KRSodium.instance().secretBox.KeyBytes)
        let symmetricKeyHash = symmetricKey.SHA256

        
        // encrypt the invite
        guard let inviteCiphertext:Data = KRSodium.instance().secretBox.seal(message: inviteJson,
                                                                        secretKey: symmetricKey)
        else {
            throw SigChain.Errors.inviteEncryptionFailed
        }

        // sodium secret box encrypt an invite
        let membershipInvitation = SigChain.IndirectInvitation(noncePublicKey: nonceKeyPair.publicKey,
                                                             inviteSymmetricKeyHash: symmetricKeyHash,
                                                             inviteCiphertext: inviteCiphertext,
                                                             restriction: restriction)
        
        
        return (SigChain.JoinTeamInvite(symmetricKey: symmetricKey), .invite(.indirect(membershipInvitation)))
    }

}
