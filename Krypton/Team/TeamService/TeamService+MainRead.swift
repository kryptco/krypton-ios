//
//  TeamService+MainRead.swift
//  Krypton
//
//  Created by Alex Grinman on 1/18/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

extension TeamService {
    
    
    /**
        Send a ReadBlock signedMessage to the teams service, and update the team by verifying and
        digesting any new blocks
     */
    func getVerifiedTeamUpdatesSync() throws -> TeamServiceResult<TeamService>  {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        
        return try teamIdentity.dataManager.withTransaction { return try getVerifiedTeamUpdatesSyncUnlocked(dataManager: $0) }
    }

    internal func getVerifiedTeamUpdatesSyncUnlocked(dataManager:TeamDataManager) throws -> TeamServiceResult<TeamService>  {
        let readBlocksRequest = try SigChain.ReadBlocksRequest(teamPointer: teamIdentity.teamPointer(dataManager: dataManager),
                                                               nonce: Data.random(size: 32),
                                                               token: nil)
        
        let signedMessage = try teamIdentity.sign(body: .main(.read(readBlocksRequest)))
        
        let serverResponse:ServerResponse<SigChain.ReadBlocksResponse> = server.sendSync(object: signedMessage.object, for: .sigChain)
        
        switch serverResponse {
        case .error(let error):
            return .error(error)
            
        case .success(let response):
            guard response.hasBlocks else {
                
                guard try dataManager.hasBlock(for: self.teamIdentity.checkpoint) else {
                    return .error(Errors.checkpointNotReached)
                }
                
                return .result(self)
            }
            
            // verify and append incoming blocks
            try self.teamIdentity.verifyAndProcessBlocks(response: response, dataManager: dataManager)
            
            guard response.hasMore else {
                return .result(self)
            }
            
            return try self.getVerifiedTeamUpdatesSyncUnlocked(dataManager: dataManager)
        }

    }

    
    /**
        Send a ReadBlock signedMessage to the teams service as a non-member, using the invite nonce keypair
     */
    func getTeamSync(using invite:SigChain.IndirectInvitation.Secret) throws -> TeamServiceResult<TeamService> {
        mutex.lock()
        defer { mutex.unlock() }
        
        return try teamIdentity.dataManager.withTransaction{ return try getTeamSyncUnlocked(using: invite, dataManager: $0) }
    }
    
    internal func getTeamSyncUnlocked(using invite:SigChain.IndirectInvitation.Secret, dataManager:TeamDataManager) throws -> TeamServiceResult<TeamService> {
        
        // use the invite `seed` to create a nonce sodium keypair
        guard let nonceKeypair = KRSodium.instance().sign.keyPair(seed: invite.nonceKeypairSeed.bytes) else {
            throw Errors.badInviteSeed
        }
        
        let readBlocksRequest = try SigChain.ReadBlocksRequest(teamPointer: teamIdentity.teamPointer(dataManager: dataManager),
                                                               nonce: Data.random(size: 32),
                                                               token: nil)
        
        let message = SigChain.Message(body: .main(.read(readBlocksRequest)))
        let messageData = try message.jsonData()
        
        guard let signature = KRSodium.instance().sign.signature(message: messageData.bytes, secretKey: nonceKeypair.secretKey)
            else {
                throw Errors.payloadSignature
        }
        
        let serializedMessage = try messageData.utf8String()
        let signedMessage = SigChain.SignedMessage(publicKey: nonceKeypair.publicKey.data,
                                                   message: serializedMessage,
                                                   signature: signature.data)
        
        
        
        let serverResponnse:ServerResponse<SigChain.ReadBlocksResponse> = server.sendSync(object: signedMessage.object, for: .sigChain)
        
        switch serverResponnse {
        case .error(let error):
            return .error(error)
            
        case .success(let response):
            guard response.hasBlocks else {
                guard try dataManager.hasBlock(for: self.teamIdentity.checkpoint) else {
                    return .error(Errors.checkpointNotReached)
                }

                return .result(self)
            }
            
            // verify and append incoming blocks
            try self.teamIdentity.verifyAndProcessBlocks(response: response, dataManager: dataManager)

            guard response.hasMore else {
                return .result(self)
            }
            
            return try self.getTeamSyncUnlocked(using: invite, dataManager: dataManager)
        }
        
    }
    

    
}
