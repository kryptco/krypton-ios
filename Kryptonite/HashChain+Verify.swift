//
//  HashChain+Verify.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

typealias UpdatedTeam = Team

extension HashChain.Response {
    
    func verifyAndDigestBlocks(for team:Team) throws -> UpdatedTeam {
        
        let blockDataManager = HashChainBlockManager(team: team)
        
        var updatedTeam = team
        
        var blockStart = 0
        var lastBlockHash = team.lastBlockHash
        
        if lastBlockHash == nil {
            guard blocks.count > 0 else {
                throw HashChain.Errors.missingCreateChain
            }
            
            let createBlock = blocks[0]
            
            // 1. verify the block signature
            guard try KRSodium.shared().sign.verify(message: createBlock.payload.utf8Data(), publicKey: team.publicKey, signature: createBlock.signature)
                else {
                    throw HashChain.Errors.badSignature
            }
            
            // 2. ensure the create block is a create chain payload
            guard case .create(let createChain) = try HashChain.Payload(jsonString: createBlock.payload)
            else {
                throw HashChain.Errors.missingCreateChain
            }
            
            // 3. check the team public key matches
            guard createChain.teamPublicKey == team.publicKey else {
                throw HashChain.Errors.teamPublicKeyMismatch
            }
            
            updatedTeam.info = createChain.teamInfo
            
            // add the block to the data store
            blockDataManager.add(block: createBlock)
            
            lastBlockHash = createBlock.hash()
            blockStart += 1
        }
                
        for i in blockStart ..< blocks.count {
            let nextBlock = blocks[i]
            
            // 1. Ensure it's an append block
            guard case .append(let appendBlock) = try HashChain.Payload(jsonString: nextBlock.payload) else {
                throw HashChain.Errors.unexpectedBlock
            }
            
            // handle special case for an accept invite signed by the invitation nonce keypair
            // otherwise, every other block must be signed by team public key
            var publicKey:SodiumPublicKey
            if case .acceptInvite = appendBlock.operation, let noncePublicKey = updatedTeam.lastInvitePublicKey {
                publicKey = noncePublicKey
            } else {
                publicKey = team.publicKey
            }
            
            // 2. Ensure last hash matches
            guard appendBlock.lastBlockHash == lastBlockHash else {
                throw HashChain.Errors.badBlockHash
            }
            
            
            // 3. Ensure signature verifies
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
                
            case .cancelInvite:
                updatedTeam.lastInvitePublicKey = nil
                
            case .acceptInvite(let member):
                blockDataManager.add(member: member, blockHash: nextBlock.hash())
                
            case .addMember(let member):
                blockDataManager.add(member: member, blockHash: nextBlock.hash())

            case .removeMember(let memberPublicKey):
                blockDataManager.remove(member: memberPublicKey)
                
            case .setPolicy(let policy):
                updatedTeam.policy = policy
                
            case .setTeamInfo(let info):
                updatedTeam.info = info
            
            case .pinHostKey(let host):
                blockDataManager.pin(sshHostKey: host, blockHash: nextBlock.hash())
                
            case .unpinHostKey(let host):
                blockDataManager.unpin(sshHostKey: host)
            }
            
            // add the block to the data store
            blockDataManager.add(block: nextBlock)
            
            lastBlockHash = nextBlock.hash()
        }
        
        updatedTeam.lastBlockHash = lastBlockHash
        
        return updatedTeam
    }

}
