//
//  HashChain+WriteLog.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension TeamIdentity {
    mutating func writeLog(data:Data) throws {
        guard let lastLogBlockHash = self.logCheckpoint else {
            throw HashChain.Errors.missingLastLogBlockHash
        }
        
        guard let logCiphertext:Data = try KRSodium.shared().secretBox.seal(message: data, secretKey: self.logEncryptionKey) else {
            throw HashChain.Errors.logEncryptionFailed
        }
        
        let encryptedLog = HashChain.LogOperation.encryptLog(HashChain.EncryptedLog(ciphertext: logCiphertext))
        let payload = HashChain.AppendLogBlock(lastBlockHash: lastLogBlockHash, operation: encryptedLog)
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
