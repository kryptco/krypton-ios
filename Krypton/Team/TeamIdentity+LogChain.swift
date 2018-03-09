//
//  SigChain+WriteLog.swift
//  Krypton
//
//  Created by Alex Grinman on 9/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation


enum AuditLogSendingErrors:Error {
    case loggingDisabled
}

extension TeamIdentity {
    
    /**
        Queue a new log and try to send unsent logs
     */
    mutating func writeAndSendLog(auditLog:Audit.Log) throws {
        
        // first record the audit log data
        try self.dataManager.withTransaction {
            guard  try $0.fetchTeam().commandEncryptedLoggingEnabled
                else {
                    throw AuditLogSendingErrors.loggingDisabled
            }
            
            let logData = try auditLog.jsonData()
            try $0.createAuditLog(unsentAuditLog: UnsentAuditLog(data: logData, date: Date(), dataHash: logData.SHA256))
        }
        
        // now try to send any queued audit logs
        dispatchAsync {
            do {
                try TeamService.shared().sendUnsentLogBlocksSync()
                log("log blocks sent succesfully")
            } catch {
                log("could not send log blocks: \(error)", .error)
            }
        }
    }

    
    /**
        Verify new log blocks
    */
    mutating func verifyAndProcessNewLogBlock(block:SigChain.SignedMessage, dataManager:TeamDataManager) throws {
        
        // first load the message
        let message = try SigChain.Message(jsonString: block.message)
        
        // 0. check protocol version
        guard !message.header.protocolVersion.isMajorUpgrade(from: SigChain.protocolVersion) else {
            throw SigChain.Errors.majorVersionIncompatible
        }
        
        // 1. ensure the block is a logChain block
        guard case .log(let logChainBody) = message.body
            else {
                throw SigChain.Errors.notLogChainBlock
        }
        
        // 2. verify it's authored by me
        guard block.publicKey == self.publicKey else {
            throw SigChain.Errors.signerNotLogChainAuthor
        }
        
        // 3. verify the block signature
        guard try KRSodium.instance().sign.verify(message: block.message.utf8Data(),
                                                  publicKey: self.publicKey,
                                                  signature: block.signature)
        else {
            throw SigChain.Errors.badSignature
        }
        
        
        // if no last log block hash, expect a genesis
        guard let lastLogBlockHash = try dataManager.lastLogBlockHash() else {
            guard case .create(let logGenesis) = logChainBody
            else {
                throw SigChain.Errors.expectedLogChainGenesis
            }
            
            switch logGenesis.teamPointer {
            case .publicKey(let teamPublicKey):
                guard self.initialTeamPublicKey == teamPublicKey else {
                    throw SigChain.Errors.missingTeamPointerBlockHash
                }
            case .lastBlockHash(let blockHash):
                guard try dataManager.hasBlock(for: blockHash) else {
                    throw SigChain.Errors.missingTeamPointerBlockHash
                }
            }
            
            // find a wrapped key for ourselves
            if  let wrappedKey = (logGenesis.wrappedKeys.filter { $0.recipientPublicKey == self.encryptionPublicKey }).first,
                case .logEncryptionKey(let logEncryptionKey) = try self.open(boxedMessage: SigChain.BoxedMessage(wrappedKey: wrappedKey,
                                                                                                                 senderPublicKey: self.encryptionPublicKey))
            {
                try dataManager.setLogEncryptionKey(key: logEncryptionKey)
            }
            
        
            // finally append the log block
            try dataManager.appendLog(signedMessage: block)
            
            return
        }
        
        // otherwise we're appending
        guard case .append(let logBlock) = logChainBody
        else {
            throw SigChain.Errors.expectedLogChainAppend
        }
        
        // ensure the last block hash matches
        guard logBlock.lastBlockHash == lastLogBlockHash else {
            throw SigChain.Errors.badLogBlockHash
        }
        
        switch logBlock.operation {
        case .addWrappedKeys(let wrappedKeys):
            if  let wrappedKey = (wrappedKeys.filter { $0.recipientPublicKey == self.encryptionPublicKey }).first,
                case .logEncryptionKey(let logEncryptionKey) = try self.open(boxedMessage: SigChain.BoxedMessage(wrappedKey: wrappedKey,
                                                                                                                 senderPublicKey: self.encryptionPublicKey))
            {
                try dataManager.setLogEncryptionKey(key: logEncryptionKey)
            }
            
            // update the tracked wrapped public keys
            let currentlyWrappedTo = try Set<SodiumBoxPublicKey>(dataManager.fetchTrackedPublicKeysWithWrappedLogEncryptionKey())
            let newlyWrappedTo = currentlyWrappedTo.union(Set<SodiumBoxPublicKey>(wrappedKeys.map { $0.recipientPublicKey }))
            try dataManager.setTrackedPublicKeysForWrappedLogEncryptionKey(publicKeys: [SodiumBoxPublicKey](newlyWrappedTo))

            
        case .rotateKey(let wrappedKeys):
            guard let wrappedKey = (wrappedKeys.filter { $0.recipientPublicKey == self.encryptionPublicKey }).first else {
                throw SigChain.Errors.missingLogChainWrappedKey
            }

            guard case .logEncryptionKey(let logEncryptionKey) = try self.open(boxedMessage: SigChain.BoxedMessage(wrappedKey: wrappedKey,
                                                                                                                   senderPublicKey: self.encryptionPublicKey))
            else {
                throw SigChain.Errors.badLogChainWrappedKey
            }
            
            try dataManager.setLogEncryptionKey(key: logEncryptionKey)
            
            // update the tracked wrapped public keys
            try dataManager.setTrackedPublicKeysForWrappedLogEncryptionKey(publicKeys: wrappedKeys.map { $0.recipientPublicKey })
            
        case .encryptLog(_):
            break
        }
        
        // finally append the log block
        try dataManager.appendLog(signedMessage: block)
    }
    
    // MARK: Main routine for create the next log block
    // returns a SignedMessage for the next LogBlock to push, and a optional UnsentAuditLog
    mutating func nextLogBlockSignedMessage(dataManager: TeamDataManager) throws -> (SigChain.SignedMessage?, UnsentAuditLog?) {
        
        // check we have unsent logs to encrypt
        guard let unsent = try dataManager.fetchNextUnsentAuditLog() else {
            return (nil, nil) // no more data to send
        }

        // Do we need to create a  genesis block
        guard let lastLogBlockHash = try dataManager.lastLogBlockHash() else {
            
            guard let newLogEncryptionKey = KRSodium.instance().secretBox.key() else {
                throw SigChain.Errors.rotateKeyGeneration
            }
            
            try dataManager.setLogEncryptionKey(key: newLogEncryptionKey)
            let signedMessage = try genesisLogBlockSignedMessage(logEncryptionKey: newLogEncryptionKey, dataManager: dataManager)
            
            return (signedMessage, nil)
        }
        
        // Decide if we need to rotate
        // If we don't have a log encryption key, we need to generate one -- so we need to rotate
        // If an admin has been demoted/removed since we last checked, we need to rotate
        let currentlyWrappedTo = try Set<SodiumBoxPublicKey>(dataManager.fetchTrackedPublicKeysWithWrappedLogEncryptionKey())
        let adminsAndMe = try Set<SodiumBoxPublicKey>(dataManager.fetchAdmins().map { $0.encryptionPublicKey } + [self.encryptionPublicKey])
        
        guard   let logEncryptionKey = try dataManager.getLogEncryptionKey(),
                currentlyWrappedTo.subtracting(adminsAndMe).isEmpty
        else { // ROTATE
            // rotate the log encryption key
            guard let newLogEncryptionKey = KRSodium.instance().secretBox.key() else {
                throw SigChain.Errors.rotateKeyGeneration
            }
            
            // set the new log encryption key
            try dataManager.setLogEncryptionKey(key: newLogEncryptionKey)
            
            // re-wrap the new log encryption key to remaining admins
            let publicKeysToWrapTo = [SodiumBoxPublicKey](adminsAndMe)
            let wrappedKeys:[SigChain.WrappedKey] = try publicKeysToWrapTo.map {
                try self.seal(plaintextBody: .logEncryptionKey(newLogEncryptionKey), recipientPublicKey: $0).toWrappedKey()
            }
            
            // track new public keys
            try dataManager.setTrackedPublicKeysForWrappedLogEncryptionKey(publicKeys: publicKeysToWrapTo)
            
            // create a signed message
            let signedMessage = try self.sign(logOperation: .rotateKey(wrappedKeys), lastLogBlockHash: lastLogBlockHash)
            
            return (signedMessage, nil)
        }
        
        // No rotation necessary
        // Next: decide if we need to add wrapped keys
        let publicKeysToWrapTo = [SodiumBoxPublicKey](adminsAndMe.subtracting(currentlyWrappedTo))
        
        guard publicKeysToWrapTo.isEmpty else { // ADD WRAPPED KEYS
            // track new public keys
            try dataManager.setTrackedPublicKeysForWrappedLogEncryptionKey(publicKeys: [SodiumBoxPublicKey](adminsAndMe))

            let signedMessage =  try addWrappedKeysLogBlockSignedMessage(publicKeys: publicKeysToWrapTo,
                                                                        logEncryptionKey: logEncryptionKey,
                                                                        lastLogBlockHash: lastLogBlockHash,
                                                                        dataManager: dataManager)
            
            return (signedMessage, nil)
        }
        
        
        // ENCRYPT LOG
        let signedMessage = try encryptLogBlockSignedMessage(for: unsent.data,
                                                             logEncryptionKey: logEncryptionKey,
                                                             lastLogBlockHash: lastLogBlockHash,
                                                             dataManager: dataManager)
        return (signedMessage, unsent)
    }

    // MARK: Helper functions
    
    func genesisLogBlockSignedMessage(logEncryptionKey:SodiumSecretBoxKey, dataManager: TeamDataManager) throws -> SigChain.SignedMessage {
        
        // create the current epoch of wrapped keys
        let adminsAndMe = try Set<SodiumBoxPublicKey>(dataManager.fetchAdmins().map { $0.encryptionPublicKey } + [self.encryptionPublicKey])
        let wrappedKeys:[SigChain.WrappedKey] = try adminsAndMe.map {
            try self.seal(plaintextBody: .logEncryptionKey(logEncryptionKey), recipientPublicKey: $0).toWrappedKey()
        }
        
        // track new public keys
        try dataManager.setTrackedPublicKeysForWrappedLogEncryptionKey(publicKeys: [SodiumBoxPublicKey](adminsAndMe))

        // create a signed message
        let logGenesis = SigChain.GenesisLogBlock(teamPointer: .publicKey(self.initialTeamPublicKey),
                                                  wrappedKeys: wrappedKeys)
        let signedMessage = try self.sign(logChainBody: .create(logGenesis))
        return signedMessage
    }
    
    /**
        Create an `AddWrappedKeys` block
     */
    func addWrappedKeysLogBlockSignedMessage(publicKeys:[SodiumBoxPublicKey], logEncryptionKey:SodiumSecretBoxKey, lastLogBlockHash:Data, dataManager: TeamDataManager) throws -> SigChain.SignedMessage {
        
        // create the wrapped keys  
        let wrappedKeys:[SigChain.WrappedKey] = try publicKeys.map {
            try self.seal(plaintextBody: .logEncryptionKey(logEncryptionKey), recipientPublicKey: $0).toWrappedKey()
        }
        
        // create a signed message
        let logBlock = SigChain.LogBlock(lastBlockHash: lastLogBlockHash, operation: .addWrappedKeys(wrappedKeys))
        let signedMessage = try self.sign(logChainBody: .append(logBlock))
        return signedMessage
    }

    
    func encryptLogBlockSignedMessage(for data:Data, logEncryptionKey:SodiumSecretBoxKey, lastLogBlockHash: Data, dataManager: TeamDataManager) throws -> SigChain.SignedMessage {
        
        // log the actual data now
        guard let logCiphertext:Data = KRSodium.instance().secretBox.seal(message: data, secretKey: logEncryptionKey) else {
            throw SigChain.Errors.logEncryptionFailed
        }
        
        let signedMessage = try self.sign(logOperation: .encryptLog(SigChain.EncryptedLog(ciphertext: logCiphertext)),
                                          lastLogBlockHash: lastLogBlockHash)
        return signedMessage
    }
    
    /**
        Sign a log append operation
     */
    func sign(logOperation: SigChain.LogOperation, lastLogBlockHash:Data) throws -> SigChain.SignedMessage {
        let logBlock = SigChain.LogBlock(lastBlockHash: lastLogBlockHash, operation: logOperation)
        return try self.sign(logChainBody: .append(logBlock))
    }
    
    /**
        Sign a log chain body
     */
    func sign(logChainBody: SigChain.LogChain) throws -> SigChain.SignedMessage {
        return try self.sign(body: .log(logChainBody))
    }
}


