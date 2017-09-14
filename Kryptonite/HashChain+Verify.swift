//
//  HashChain+Verify.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

/// verify incoming blocks for a new team, with an invite
extension TeamInvite {
    
}

/// verify incoming blocks with an existing team identity
extension TeamIdentity {
    
    mutating func verifyAndProcessBlocks(response:HashChain.Response) throws {
        
        let blocks = response.blocks
        
        var updatedTeam = self.team
        var lastBlockHash = try self.lastBlockHash()
        
        var blockStart = 0
        if lastBlockHash == nil {
            guard blocks.count > 0 else {
                throw HashChain.Errors.missingCreateChain
            }
            
            let createBlock = blocks[0]
            
            // 1. ensure the create block is a create chain payload
            guard case .create(let createChain) = try HashChain.Payload(jsonString: createBlock.payload)
                else {
                    throw HashChain.Errors.missingCreateChain
            }

            // 2. verify the block signature
            guard try KRSodium.shared().sign.verify(message: createBlock.payload.utf8Data(), publicKey: initialTeamPublicKey, signature: createBlock.signature)
                else {
                    throw HashChain.Errors.badSignature
            }
            
            
            // 3. add the original admin as a public key
            guard createChain.teamPublicKey == initialTeamPublicKey else {
                throw HashChain.Errors.teamPublicKeyMismatch
            }
            
            updatedTeam.info = createChain.teamInfo
            
            // add the block to the data store
            try dataManager.create(team: updatedTeam, block: createBlock)
            
            lastBlockHash = createBlock.hash()
            blockStart += 1
        }
                
        for i in blockStart ..< blocks.count {
            let nextBlock = blocks[i]
            
            // 1. Ensure it's an append block
            guard case .append(let appendBlock) = try HashChain.Payload(jsonString: nextBlock.payload) else {
                throw HashChain.Errors.unexpectedBlock
            }
            
            // 2. Ensure the signer has permission
            // - either the signer is an admin OR
            // - handle special case for an accept invite signed by the invitation nonce keypair
            
            var publicKey:SodiumPublicKey
            if case .acceptInvite = appendBlock.operation, let noncePublicKey = updatedTeam.lastInvitePublicKey {
                publicKey = noncePublicKey
            } else {
                guard try dataManager.isAdmin(for: nextBlock.publicKey) else {
                    throw HashChain.Errors.signerNotAdmin
                }
                
                publicKey = nextBlock.publicKey
            }
            
            // 3. Ensure last hash matches
            guard appendBlock.lastBlockHash == lastBlockHash else {
                throw HashChain.Errors.badBlockHash
            }
            
            
            // 4. Ensure signature verifies
            let verified = try KRSodium.shared().sign.verify(message: nextBlock.payload.utf8Data(),
                                                             publicKey: publicKey,
                                                             signature: nextBlock.signature)
            guard verified
                else {
                    throw HashChain.Errors.badSignature
            }
            
            
            // 4. digest the operation
            switch appendBlock.operation {
            case .inviteMember(let invite):
                updatedTeam.lastInvitePublicKey = invite.noncePublicKey
                try dataManager.append(block: nextBlock)
                
            case .cancelInvite:
                updatedTeam.lastInvitePublicKey = nil
                try dataManager.append(block: nextBlock)
                
            case .acceptInvite(let member):
                try dataManager.add(member: member, block: nextBlock)
                
            case .addMember(let member):
                try dataManager.add(member: member, block: nextBlock)

            case .removeMember(let memberPublicKey):
                try dataManager.remove(member: memberPublicKey, block: nextBlock)
                
            case .setPolicy(let policy):
                updatedTeam.policy = policy
                try dataManager.append(block: nextBlock)
                
            case .setTeamInfo(let info):
                updatedTeam.info = info
                try dataManager.append(block: nextBlock)
                
            case .pinHostKey(let host):
                try dataManager.pin(sshHostKey: host, block: nextBlock)
                
            case .unpinHostKey(let host):
                try dataManager.unpin(sshHostKey: host, block: nextBlock)

            case .addLoggingEndpoint(let endpoint):
                updatedTeam.loggingEndpoints.append(endpoint)
                try dataManager.append(block: nextBlock)

            case .removeLoggingEndpoint(let endpoint):
                if let idx = updatedTeam.loggingEndpoints.index(of: endpoint) {
                    updatedTeam.loggingEndpoints.remove(at: idx)
                }
                try dataManager.append(block: nextBlock)
                
            case .addAdmin(let admin):
                try dataManager.add(admin: admin, block: nextBlock)
                
            case .removeAdmin(let admin):
                try dataManager.remove(admin: admin, block: nextBlock)
            }
            
            lastBlockHash = nextBlock.hash()
        }
        
        try set(team: updatedTeam)
    }

}
