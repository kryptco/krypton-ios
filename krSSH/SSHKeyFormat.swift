//
//  SecKeyECASN1.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation
import Security


//MARK: SSH Key Type

enum SSHKeyType:String {
    case rsa = "ssh-rsa"
    
    func bytes() throws -> [UInt8] {
        guard  let keyTypeBytes = self.rawValue.data(using: String.Encoding.utf8)?.bytes
        else {
            throw CryptoError.encoding
        }

        return keyTypeBytes
    }
}

//MARK: SSH Key Format
typealias SSHWireFormat = Data
typealias SSHAuthorizedFormat = String

extension SSHAuthorizedFormat {
    func toWire() throws -> SSHWireFormat {
        let components = self.components(separatedBy: " ")
        guard components.count == 2 else {
            throw CryptoError.encoding
        }
        
        return try components[1].fromBase64()
    }
    
    func byAdding(comment:String) -> SSHAuthorizedFormat{
        return "\(self) \(comment)"
    }
    
    func byRemovingComment() throws -> (SSHAuthorizedFormat, String) {
        let components = self.components(separatedBy: " ")
        guard components.count > 2 else {
            throw CryptoError.encoding
        }
        
        let authorized = "\(components[0]) \(components[1])"
        let comment = components[2]
        
        return (authorized, comment)
    }
}


extension SSHWireFormat {
    func fingerprint() -> Data {
        return self.SHA256
    }
    
    func toAuthorized() -> SSHAuthorizedFormat {
        return "\(SSHKeyType.rsa.rawValue) \(self.toBase64())"
    }

}

//MARK: PublicKey + SSH

extension PublicKey {
    
    func wireFormat() throws -> SSHWireFormat {
        let components = try self.splitIntoComponents()

        // ssh-wire-encoding(ssh-rsa, public exponent, modulus)
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x07]
        wireBytes.append(contentsOf: try SSHKeyType.rsa.bytes())

        wireBytes.append(contentsOf: components.exponent.bigEndianByteSize())
        wireBytes.append(contentsOf: components.exponent.bytes)

        wireBytes.append(contentsOf: components.modulus.bigEndianByteSize())
        wireBytes.append(contentsOf: components.modulus.bytes)

        return Data(bytes: wireBytes)
    }
    
    func authorizedFormat() throws -> SSHAuthorizedFormat {
        return try self.wireFormat().toAuthorized()
    }
    
    func fingerprint() throws -> Data {
        return try self.wireFormat().fingerprint()
    }
}
