//
//  HashChain+Verify.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

/// verify incoming blocks with an existing team identity
extension TeamIdentity {
    
    mutating func verifyAndProcessBlocks(response:HashChain.Response) throws {
        
        let blocks = response.blocks
        
        var updatedTeam = try self.team()
        var lastBlockHash = try self.lastBlockHash()
        
        var blockStart = 0
        if lastBlockHash == nil {
            guard blocks.count > 0 else {
                throw HashChain.Errors.missingCreateChain
            }
            
            let createBlock = blocks[0]
            
            // 1. ensure the create block is a create chain payload
            guard case .createChain(let createChain) = try HashChain.Payload(jsonString: createBlock.payload)
                else {
                    throw HashChain.Errors.missingCreateChain
            }

            // 2. verify the block signature
            guard try KRSodium.shared().sign.verify(message: createBlock.payload.utf8Data(), publicKey: initialTeamPublicKey, signature: createBlock.signature)
                else {
                    throw HashChain.Errors.badSignature
            }
            
            
            // 3. add the original admin as a public key
            guard createChain.creator.publicKey == initialTeamPublicKey else {
                throw HashChain.Errors.teamPublicKeyMismatch
            }
            
            updatedTeam.info = createChain.teamInfo
            
            // add the block to the data store
            try dataManager.create(team: updatedTeam, creator: createChain.creator, block: createBlock)
            lastBlockHash = createBlock.hash()
            blockStart += 1
        }
                
        for i in blockStart ..< blocks.count {
            let nextBlock = blocks[i]
            
            // 1. Ensure it's an append block
            guard case .appendBlock(let appendBlock) = try HashChain.Payload(jsonString: nextBlock.payload) else {
                throw HashChain.Errors.unexpectedBlock
            }
            
            // 2. Ensure the signer has permission
            // - either the signer is an admin OR
            // - handle special case for an accept invite signed by the invitation nonce keypair
            
            var publicKey:SodiumSignPublicKey
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
                
                // wrap the log encryption key for each admin
                var wrappedKeys:[HashChain.WrappedKey] = []
                
                for admin in try dataManager.fetchAdmins() {
                    let ciphertext = try self.logEncryptionKey.wrap(to: admin.encryptionPublicKey)
                    let wrappedKey = HashChain.WrappedKey(publicKey: admin.encryptionPublicKey, ciphertext: ciphertext)
                    wrappedKeys.append(wrappedKey)
                }
                
                // wrap the log encryption key for self
                let ciphertext = try self.logEncryptionKey.wrap(to: self.encryptionKeyPair.publicKey)
                let selfWrappedKey = HashChain.WrappedKey(publicKey: self.encryptionKeyPair.publicKey, ciphertext: ciphertext)
                wrappedKeys.append(selfWrappedKey)

                // create the log chain
                let createLogChain = HashChain.CreateLogChain(teamPointer: HashChain.TeamPointer.lastBlockHash(nextBlock.hash()), wrappedKeys: wrappedKeys)
                let payload = HashChain.Payload.createLogChain(createLogChain)
                let payloadData = try payload.jsonData()
                
                // sign the payload
                guard let payloadSignature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: self.keyPair.secretKey)
                else {
                    throw HashChain.Errors.payloadSignatureFailed
                }
                
                // send the payload request
                let payloadDataString = try payloadData.utf8String()

                // add log block
                let logBlock = HashChain.LogBlock(payload: payloadDataString, signature: payloadSignature, log: Data())
                try dataManager.appendLog(block: logBlock)
                self.logCheckpoint = logBlock.hash()

            case .removeLoggingEndpoint(let endpoint):
                if let idx = updatedTeam.loggingEndpoints.index(of: endpoint) {
                    updatedTeam.loggingEndpoints.remove(at: idx)
                }
                try dataManager.append(block: nextBlock)
                
            case .addAdmin(let admin):
                // add the new admin
                try dataManager.add(admin: admin, block: nextBlock)
                
                // handle log new wrapped key if we have a log chain
                if let lastLogBlockHash = self.logCheckpoint {
                    
                    // fetch the admin's member identity
                    guard let adminIdentity = try dataManager.fetchMemberIdentity(for: admin) else {
                        throw HashChain.Errors.memberDoesNotExist
                    }

                    // wrap the log encryption key to this new member
                    let ciphertext = try self.logEncryptionKey.wrap(to: adminIdentity.encryptionPublicKey)
                    let wrappedKey = HashChain.WrappedKey(publicKey: adminIdentity.encryptionPublicKey, ciphertext: ciphertext)
                    
                    // prepare the addWrappedKeys payload
                    let addWrappedKeys = HashChain.LogOperation.addWrappedKeys([wrappedKey])
                    let payload = HashChain.AppendLogBlock(lastBlockHash: lastLogBlockHash, operation: addWrappedKeys)
                    let payloadData = try payload.jsonData()
                    
                    // sign the payload
                    guard let payloadSignature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: self.keyPair.secretKey)
                        else {
                            throw HashChain.Errors.payloadSignatureFailed
                    }
                    
                    // send the payload request
                    let payloadDataString = try payloadData.utf8String()
                    
                    // add the log block
                    let logBlock = HashChain.LogBlock(payload: payloadDataString, signature: payloadSignature, log: Data())
                    try dataManager.appendLog(block: logBlock)
                    self.logCheckpoint = logBlock.hash()
                }
                
                
            case .removeMember(let memberPublicKey):
                let memberIsAdmin = try dataManager.isAdmin(for: memberPublicKey)
                try dataManager.remove(member: memberPublicKey, block: nextBlock)

                // if the member is an admin and we have a log chain, we must rotate log encryption key
                if let lastLogBlockHash = self.logCheckpoint, memberIsAdmin {
                    
                    // rotate the log encryption key
                    guard let newLogEncryptionKey = try KRSodium.shared().secretBox.key() else {
                        throw HashChain.Errors.rotateKeyGeneration
                    }
                    
                    // set the new log encryption key
                    self.logEncryptionKey = newLogEncryptionKey
                    
                    // re-wrap the new log encryption key remaining admins
                    let existingAdmins = try dataManager.fetchAdmins().filter({ $0.publicKey != memberPublicKey })
                    
                    var wrappedKeys:[HashChain.WrappedKey] = []
                    for existingAdmin in existingAdmins {
                        let ciphertext = try newLogEncryptionKey.wrap(to: existingAdmin.encryptionPublicKey)
                        let wrappedKey = HashChain.WrappedKey(publicKey: existingAdmin.encryptionPublicKey, ciphertext: ciphertext)
                        wrappedKeys.append(wrappedKey)
                    }
                    
                    // wrap the log encryption key for self
                    let ciphertext = try self.logEncryptionKey.wrap(to: self.encryptionKeyPair.publicKey)
                    let selfWrappedKey = HashChain.WrappedKey(publicKey: self.encryptionKeyPair.publicKey, ciphertext: ciphertext)
                    wrappedKeys.append(selfWrappedKey)

                    
                    // prepare the addWrappedKeys payload
                    let rotateKey = HashChain.LogOperation.rotateKey(wrappedKeys)
                    let payload = HashChain.AppendLogBlock(lastBlockHash: lastLogBlockHash, operation: rotateKey)
                    let payloadData = try payload.jsonData()
                    
                    // sign the payload
                    guard let payloadSignature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: self.keyPair.secretKey)
                        else {
                            throw HashChain.Errors.payloadSignatureFailed
                    }
                    
                    // send the payload request
                    let payloadDataString = try payloadData.utf8String()
                    
                    // add the log block
                    let logBlock = HashChain.LogBlock(payload: payloadDataString, signature: payloadSignature, log: Data())
                    try dataManager.appendLog(block: logBlock)
                    self.logCheckpoint = logBlock.hash()
                }


            case .removeAdmin(let admin):
                // remove the admin
                try dataManager.remove(admin: admin, block: nextBlock)
                
                // handle log key rotation if we have a log chain
                if let lastLogBlockHash = self.logCheckpoint {
                    
                    // rotate the log encryption key
                    guard let newLogEncryptionKey = try KRSodium.shared().secretBox.key() else {
                        throw HashChain.Errors.rotateKeyGeneration
                    }
                    
                    // set the new log encryption key
                    self.logEncryptionKey = newLogEncryptionKey
                    
                    // re-wrap the new log encryption key remaining admins
                    let existingAdmins = try dataManager.fetchAdmins().filter({ $0.publicKey != admin })
                    
                    var wrappedKeys:[HashChain.WrappedKey] = []
                    for existingAdmin in existingAdmins {
                        let ciphertext = try newLogEncryptionKey.wrap(to: existingAdmin.encryptionPublicKey)
                        let wrappedKey = HashChain.WrappedKey(publicKey: existingAdmin.encryptionPublicKey, ciphertext: ciphertext)
                        wrappedKeys.append(wrappedKey)
                    }
                    
                    // wrap the log encryption key for self
                    let ciphertext = try self.logEncryptionKey.wrap(to: self.encryptionKeyPair.publicKey)
                    let selfWrappedKey = HashChain.WrappedKey(publicKey: self.encryptionKeyPair.publicKey, ciphertext: ciphertext)
                    wrappedKeys.append(selfWrappedKey)
                    
                    // prepare the addWrappedKeys payload
                    let rotateKey = HashChain.LogOperation.rotateKey(wrappedKeys)
                    let payload = HashChain.AppendLogBlock(lastBlockHash: lastLogBlockHash, operation: rotateKey)
                    let payloadData = try payload.jsonData()
                    
                    // sign the payload
                    guard let payloadSignature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: self.keyPair.secretKey)
                        else {
                            throw HashChain.Errors.payloadSignatureFailed
                    }
                    
                    // send the payload request
                    let payloadDataString = try payloadData.utf8String()
                    
                    // add the log block
                    let logBlock = HashChain.LogBlock(payload: payloadDataString, signature: payloadSignature, log: Data())
                    try dataManager.appendLog(block: logBlock)
                    self.logCheckpoint = logBlock.hash()
                }
            }
            
            lastBlockHash = nextBlock.hash()
        }
        
        try set(team: updatedTeam)
    }

}
