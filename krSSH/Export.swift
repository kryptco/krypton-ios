//
//  SecKeyECASN1.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation
import Security

extension PublicKey {
    func wireFormat() throws -> String {
    
        let components = try self.splitIntoComponents()

        guard   let keyTypeBytes = "ssh-rsa".data(using: String.Encoding.utf8)?.bytes
        else {
            throw CryptoError.encoding
        }
        
        // ssh-wire-encoding(ssh-rsa, public exponent, modulus)
        
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x07]
        wireBytes.append(contentsOf: keyTypeBytes)

        wireBytes.append(contentsOf: components.exponent.bigEndianByteSize())
        wireBytes.append(contentsOf: components.exponent.bytes)

        wireBytes.append(contentsOf: components.modulus.bigEndianByteSize())
        wireBytes.append(contentsOf: components.modulus.bytes)

        
        return "ssh-rsa \(Data(bytes: wireBytes).toBase64())"
    }
}


extension String {
    func fingerprint() throws -> Data {        
        return try self.fromBase64().SHA256
    }
}

extension Data {
    func bigEndianByteSize() -> [UInt8] {
        return stride(from: 24, through: 0, by: -8).map {
            UInt8(truncatingBitPattern: UInt32(self.count).littleEndian >> UInt32($0))
        }
    }
}


