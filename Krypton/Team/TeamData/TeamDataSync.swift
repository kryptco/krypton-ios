//
//  TeamDataSync.swift
//  Notify
//
//  Created by Alex Grinman on 3/15/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation


extension TeamIdentity {
    mutating func syncTeamDatabaseData(from: TeamDataTransaction.DBType, to: TeamDataTransaction.DBType) throws {
        try self.dataManager.withReadOnlyTransaction(dbType: from) { fromApp in
            try self.dataManager.withTransaction(dbType: to) { toApp in
                
                // main chain blocks
                while true {
                    var newBlocks:[SigChain.SignedMessage]
                    if let lastBlockHash = try toApp.lastBlockHash() {
                        newBlocks = try fromApp.fetchBlocks(after: lastBlockHash, limit: 1)
                    } else {
                        do {
                            newBlocks = [try fromApp.fetchMainChainGenesisBlock()]
                        } catch TeamDataManager.Errors.noGenesisBlock { // we don't have a main chain yet
                            break
                        } catch {
                            throw error
                        }
                    }
                    
                    if newBlocks.isEmpty {
                        break
                    }
                    
                    try self.verifyAndProcessBlocks(blocks: newBlocks, dataManager: toApp)
                }
                
                
                // log chain blocks
                while true {
                    var newLogBlocks:[SigChain.SignedMessage]
                    if let lastLogBlockHash = try toApp.lastLogBlockHash() {
                        newLogBlocks = try fromApp.fetchLogBlocks(after: lastLogBlockHash, limit: 1)
                    } else {
                        do {
                            newLogBlocks = [try fromApp.fetchLogChainGenesisBlock()]
                        } catch TeamDataManager.Errors.noLogGenesisBlock { // we don't have a log chain yet
                            break
                        } catch {
                            throw error
                        }
                    }
                    
                    if newLogBlocks.isEmpty {
                        break
                    }

                    try newLogBlocks.forEach {
                        try self.verifyAndProcessNewLogBlock(block: $0, dataManager: toApp)
                    }
                }
            }
        }
    }
}

