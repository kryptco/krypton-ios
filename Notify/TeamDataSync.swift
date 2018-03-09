//
//  TeamDataSync.swift
//  Notify
//
//  Created by Alex Grinman on 3/15/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation


extension TeamIdentity {
    mutating func syncTeamDatabaseData() throws {
        try self.dataManager.withReadOnlyTransaction(dbType: .mainApp) { mainApp in
            try self.dataManager.withTransaction { notifyApp in
                
                // main chain blocks
                while true {
                    var newBlocks:[SigChain.SignedMessage]
                    if let lastBlockHash = try notifyApp.lastBlockHash() {
                        newBlocks = try mainApp.fetchBlocks(after: lastBlockHash, limit: 1)
                    } else {
                        do {
                            newBlocks = [try mainApp.fetchMainChainGenesisBlock()]
                        } catch TeamDataManager.Errors.noGenesisBlock { // we don't have a main chain yet
                            break
                        } catch {
                            throw error
                        }
                    }
                    
                    if newBlocks.isEmpty {
                        break
                    }
                    
                    try self.verifyAndProcessBlocks(blocks: newBlocks, dataManager: notifyApp)
                }
                
                
                // log chain blocks
                while true {
                    var newLogBlocks:[SigChain.SignedMessage]
                    if let lastLogBlockHash = try notifyApp.lastLogBlockHash() {
                        newLogBlocks = try mainApp.fetchLogBlocks(after: lastLogBlockHash, limit: 1)
                    } else {
                        do {
                            newLogBlocks = [try mainApp.fetchLogChainGenesisBlock()]
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
                        try self.verifyAndProcessNewLogBlock(block: $0, dataManager: notifyApp)
                    }
                }
            }
        }
    }
}

