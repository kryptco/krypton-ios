//
//  SigChain+Verify.swift
//  Krypton
//
//  Created by Alex Grinman on 8/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

/// verify incoming blocks with an existing team identity
extension TeamIdentity {
    
    mutating func verifyAndProcessBlocks(response:SigChain.ReadBlocksResponse, dataManager:TeamDataManager) throws {
        try verifyAndProcessBlocks(blocks: response.blocks, dataManager: dataManager)
    }

    mutating func verifyAndProcessBlocks(blocks:[SigChain.SignedMessage], dataManager:TeamDataManager) throws {
        
        var lastBlockHash = try dataManager.lastBlockHash()
        
        var updatedTeam:Team

        var blockStart = 0
        if lastBlockHash == nil {
            guard blocks.count > 0 else {
                throw SigChain.Errors.missingCreateChain
            }
            
            let createMessageBlock = blocks[0]
            let createMessage = try SigChain.Message(jsonString: createMessageBlock.message)
            
            // 0. check protocol version
            guard !createMessage.header.protocolVersion.isMajorUpgrade(from: SigChain.protocolVersion) else {
                throw SigChain.Errors.majorVersionIncompatible
            }
            
            // 1. ensure the block is a main chain genesis block
            guard case .main(.create(let genesisBlock)) = createMessage.body
                else {
                    throw SigChain.Errors.missingCreateChain
            }

            // 2. verify the block signature
            guard try KRSodium.instance().sign.verify(message: createMessageBlock.message.utf8Data().bytes,
                                                      publicKey: initialTeamPublicKey,
                                                      signature: createMessageBlock.signature.bytes)
            else {
                throw SigChain.Errors.badSignature
            }
            
            
            // 3. add the original admin as a public key
            // ensure that the creator's public key matches the initial public key
            // and that the block public key matches the creator public key
            guard   genesisBlock.creator.publicKey == initialTeamPublicKey &&
                    genesisBlock.creator.publicKey.data == createMessageBlock.publicKey
            else {
                throw SigChain.Errors.teamPublicKeyMismatch
            }
            
            updatedTeam = Team(info: genesisBlock.teamInfo)
            
            // add the block to the data store
            try dataManager.create(team: updatedTeam, creator: genesisBlock.creator, block: createMessageBlock)
            lastBlockHash = createMessageBlock.hash()
            blockStart += 1
        } else {
            updatedTeam = try dataManager.fetchTeam()
        }
        
                
        for i in blockStart ..< blocks.count {
            let nextBlock = blocks[i]
            let nextMessage = try SigChain.Message(jsonString: nextBlock.message)
            
            // 0. check protocol version
            guard !nextMessage.header.protocolVersion.isMajorUpgrade(from: SigChain.protocolVersion) else {
                throw SigChain.Errors.majorVersionIncompatible
            }
            
            // 1. Ensure it's an main chain append block
            guard case .main(.append(let appendBlock)) = nextMessage.body else {
                throw SigChain.Errors.unexpectedBlock
            }
            
            // 2. Ensure the signer has permission
            // - either the signer is an admin OR
            // - protocol special case:
            //      > accept invite: signed by the invitation nonce keypair
            //      > leave: signed by member *only* for self removal
            var publicKey:SodiumSignPublicKey
            if case .acceptInvite(let identity) = appendBlock.operation {
                
                // look for matching invitation
                let invitations = try dataManager.fetchInvitationsFor(sodiumPublicKey: nextBlock.publicKey.bytes)
                
                guard let matchingInvitation = invitations.filter({
                    switch $0 {
                    case .direct(let direct):
                        guard   identity.publicKey == direct.publicKey,
                                identity.email == direct.email
                        else {
                                return false
                        }
                        
                        return true
                    case .indirect(let indirect):
                        guard indirect.noncePublicKey.data == nextBlock.publicKey else {
                            return false
                        }
                        
                        switch indirect.restriction {
                        case .domain(let domain):
                            guard let userDomain = identity.email.getEmailDomain() else {
                                return false
                            }
                            
                            return userDomain == domain
                            
                        case .emails(let emails):
                            return emails.contains(identity.email)
                        }
                    }
                }).first else {
                    throw SigChain.Errors.unknownAcceptBlockPublicKey
                }
                
                publicKey = matchingInvitation.publicKey
                
            } else if case .leave = appendBlock.operation {
                publicKey = nextBlock.publicKey.bytes
            } else {
                guard try dataManager.isAdmin(for: nextBlock.publicKey.bytes) else {
                    throw SigChain.Errors.signerNotAdmin
                }
                
                publicKey = nextBlock.publicKey.bytes
            }
            
            // 3. Ensure last hash matches
            guard appendBlock.lastBlockHash == lastBlockHash else {
                throw SigChain.Errors.badBlockHash
            }
            
            
            // 4. Ensure signature verifies
            let verified = try KRSodium.instance().sign.verify(message: nextBlock.message.utf8Data().bytes,
                                                               publicKey: publicKey,
                                                               signature: nextBlock.signature.bytes)
            guard verified else {
                throw SigChain.Errors.badSignature
            }
            
            
            // 4. digest the operation
            switch appendBlock.operation {
            case .invite(let invite):
                // invitations must have unique public keys
                guard try dataManager.fetchInvitationsFor(sodiumPublicKey: invite.publicKey).isEmpty else {
                    throw SigChain.Errors.invitePublicKeyAlreadyExists
                }
                
                switch invite {
                // direct invitations must not be created for existing members
                case .direct(let direct):
                    guard try dataManager.fetchMemberWith(email: direct.email) == nil else {
                        throw SigChain.Errors.directInviteForExistingMemberEmail
                    }
                    
                    guard try dataManager.fetchMemberIdentity(for: direct.publicKey) == nil else {
                        throw SigChain.Errors.directInviteForExistingMemberPublicKey
                    }
                    
                case .indirect(let indirect):
                    switch indirect.restriction {
                    case .emails(let emails):
                        try emails.forEach {
                            guard try dataManager.fetchMemberWith(email: $0) == nil else {
                                throw SigChain.Errors.indirectInviteForExistingMemberEmail
                            }
                        }
                    case .domain:
                        break
                    }
                }
                
                try dataManager.add(invitation: invite)
                try dataManager.append(block: nextBlock)
                
            case .closeInvitations:
                try dataManager.removeAllInvitations()
                try dataManager.append(block: nextBlock)
                
            case .acceptInvite(let member):
                // check for duplicate emails
                guard try dataManager.fetchMemberWith(email: member.email) == nil
                else {
                    throw SigChain.Errors.duplicateEmailAddress
                }
                
                // remove direct invite if exists
                try dataManager.fetchInvitationsFor(sodiumPublicKey: member.publicKey).forEach {
                    if case .direct = $0 {
                        try dataManager.removeDirectInvitations(for: member.publicKey)
                    }
                }
                
                try dataManager.add(member: member, block: nextBlock)
                
            case .setPolicy(let policy):
                updatedTeam.policy = policy
                try dataManager.append(block: nextBlock)
                
            case .setTeamInfo(let info):
                updatedTeam.info = info
                try dataManager.append(block: nextBlock)
                
            case .pinHostKey(let host):
                guard try dataManager.isPinned(hostKey: host) == false else {
                    throw SigChain.Errors.hostKeyAlreadyPinned
                }
                try dataManager.pin(sshHostKey: host, block: nextBlock)
                
            case .unpinHostKey(let host):
                guard try dataManager.isPinned(hostKey: host) else {
                    throw SigChain.Errors.hostKeyNotPinned
                }

                try dataManager.unpin(sshHostKey: host, block: nextBlock)
                
            case .promote(let admin):
                guard try dataManager.isAdmin(for: admin) == false else {
                    throw SigChain.Errors.memberIsAlreadyAdmin
                }
                
                // add the new admin
                try dataManager.add(admin: admin, block: nextBlock)
                
            case .leave:
                let memberPublicKey = nextBlock.publicKey.bytes
                
                guard try dataManager.fetchMemberIdentity(for: memberPublicKey) != nil else {
                    throw SigChain.Errors.memberDoesNotExist
                }

                try dataManager.remove(member: memberPublicKey, block: nextBlock)
                
            case .remove(let memberPublicKey):
                
                // check that admin is not removing self
                guard memberPublicKey.data != nextBlock.publicKey else {
                    throw SigChain.Errors.signerCannotRemoveSelf
                }
                
                // check that the member exists
                guard try dataManager.fetchMemberIdentity(for: memberPublicKey) != nil else {
                    throw SigChain.Errors.memberDoesNotExist
                }
                
                // when a member is removed: close all invitations
                try dataManager.removeAllInvitations()
                try dataManager.remove(member: memberPublicKey, block: nextBlock)

            case .demote(let admin):
                guard try dataManager.isAdmin(for: admin) else {
                    throw SigChain.Errors.memberNotAdmin
                }

                // remove the admin
                try dataManager.remove(admin: admin, block: nextBlock)
                
            case .addLoggingEndpoint(let endpoint):
                guard updatedTeam.loggingEndpoints.contains(endpoint) == false else {
                    throw SigChain.Errors.loggingEndpointAlreadyExists
                }
                
                updatedTeam.loggingEndpoints.insert(endpoint)
                try dataManager.append(block: nextBlock)
                
            case .removeLoggingEndpoint(let endpoint):
                guard updatedTeam.loggingEndpoints.contains(endpoint) else {
                    throw SigChain.Errors.loggingEndpointDoesNotExist
                }
                
                // clear any unsent audit logs
                try dataManager.clearAllUnsentAuditLogs()

                updatedTeam.loggingEndpoints.remove(endpoint)
                try dataManager.append(block: nextBlock)
            }
            
            lastBlockHash = nextBlock.hash()
        }
        
        try dataManager.set(team: updatedTeam)
    }
    
}
