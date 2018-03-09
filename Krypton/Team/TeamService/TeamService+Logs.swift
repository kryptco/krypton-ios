//
//  TeamService+Logs.swift
//  Krypton
//
//  Created by Alex Grinman on 1/18/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

// Send Encrypted Audit Logs

extension TeamService {
    
    
    private func readLogBlocks(logBlockHash: Data?) throws -> SigChain.ReadLogBlocksResponse {
        
        var pointer:SigChain.LogChainPointer
        if let hash = logBlockHash {
            pointer = .lastBlockHash(hash)
        } else {
            pointer = .genesisBlock(SigChain.LogChainGenesisPointer(teamPublicKey: self.teamIdentity.initialTeamPublicKey,
                                                                    memberPublicKey: self.teamIdentity.publicKey))
        }
        
        let readRequest = try SigChain.ReadLogBlocksRequest(nonce: Data.random(size: 32), filter: .member(pointer))
        let signedMessage = try self.teamIdentity.sign(body: .log(.read(readRequest)))
        
        let serverResponse:ServerResponse<SigChain.ReadLogBlocksResponse> = server.sendSync(object: signedMessage.object, for: .sigChain)
        
        switch serverResponse {
        case .error(let error):
            throw error

        case .success(let readResponse):
            return readResponse
        }
    }
    
    func getNewAuditLogsSync() throws {
        
        while true {
            let lastBlockHash = try self.teamIdentity.dataManager.withTransaction { try $0.lastLogBlockHash() }
            let readLogsResponse = try readLogBlocks(logBlockHash: lastBlockHash)

            // verify and append incoming blocks
            let shouldContinue:Bool = try self.teamIdentity.dataManager.withTransaction { dataManager in
                try readLogsResponse.logBlocks.forEach {
                    try self.teamIdentity.verifyAndProcessNewLogBlock(block: $0, dataManager: dataManager)
                }
                
                return readLogsResponse.more && !readLogsResponse.logBlocks.isEmpty
            }
            
            guard shouldContinue else {
                return
            }
        }
    }
    
    func sendUnsentLogBlocksSync() throws {
        defer { self.mutex.unlock() }
        mutex.lock()

        // first read any logs we might not have
        try getNewAuditLogsSync()

        while true {
            // try to get a logBlock and an unsent log
            let (logBlock, unsentLog) = try teamIdentity.dataManager.withTransaction {
                return try self.teamIdentity.nextLogBlockSignedMessage(dataManager: $0)
            }
            
            // check we have a block to send
            guard let nextLogBlock = logBlock else {
                return
            }
            
            let serverResponse:ServerResponse<EmptyResponse> = server.sendSync(object: nextLogBlock.object, for: .sigChain)
            
            switch serverResponse {
            case .error(let error):
                throw error
            case .success:
                try teamIdentity.dataManager.withTransaction {
                    try self.teamIdentity.verifyAndProcessNewLogBlock(block: nextLogBlock, dataManager: $0)
                    
                    // if it's a raw log mark that we have it sent.
                    if let hash = unsentLog?.dataHash {
                        try $0.markAuditLogSent(dataHash: hash)
                    }
                }
            }
        }
        
    } 
}
