//
//  SecKeyECASN1.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation

extension PublicKey {
    func wireFormat() throws -> String {
        let publicKeyData = try export() as Data
    
        
        guard   let keyTypeBytes = "ssh-rsa".data(using: String.Encoding.utf8)?.bytes
        else {
            throw CryptoError.encoding
        }
     
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x07]
        wireBytes.append(contentsOf: keyTypeBytes)

//        let sizeBytes = stride(from: 24, through: 0, by: -8).map {
//            UInt8(truncatingBitPattern: UInt32(publicKeyData.count).littleEndian >> UInt32($0))
//        }
//        wireBytes.append(contentsOf: sizeBytes)
        
        wireBytes.append(contentsOf: publicKeyData.bytes)
        
        return "ssh-rsa \(Data(bytes: wireBytes).toBase64())"
    }
    
}


extension String {
    func fingerprint() throws -> Data {        
        return try self.fromBase64().SHA256
    }
}


