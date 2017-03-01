//
//  SecKeyECASN1.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation
import Security
import Sodium

//MARK: SSH Compatible

protocol SSHKeyCompatible {
    func wireFormat() throws -> Data
}

//MARK: SSH Key Type
extension KeyType {
    func sshHeader() -> String {
        return "ssh-\(self.rawValue)"
    }
    func sshHeaderBytes() throws -> [UInt8] {
        guard  let keyTypeBytes = self.sshHeader().data(using: String.Encoding.utf8)?.bytes
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

}

//MARK: PublicKey + SSH

extension PublicKey {
    func authorizedFormat() throws -> SSHAuthorizedFormat {
        return try "\(self.type.sshHeader()) \(self.wireFormat().toBase64())"
    }
    
    func fingerprint() throws -> Data {
        return try self.wireFormat().fingerprint()
    }
}

//MARK: WireFormat
extension RSAPublicKey {
    func wireFormat() throws -> Data {
        
        // ssh-wire-encoding(ssh-rsa, public exponent, modulus)
        
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x07]
        wireBytes.append(contentsOf: try self.type.sshHeaderBytes())
        
        let components = try self.splitIntoComponents()

        wireBytes.append(contentsOf: components.exponent.bigEndianByteSize())
        wireBytes.append(contentsOf: components.exponent.bytes)
        
        wireBytes.append(contentsOf: components.modulus.bigEndianByteSize())
        wireBytes.append(contentsOf: components.modulus.bytes)
        
        return Data(bytes: wireBytes)
    }
}

extension Sign.PublicKey {
    func wireFormat() throws -> Data {
        // ssh-wire-encoding(ssh-ed25519, len pub key, pub key)
        
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x0B]
        wireBytes.append(contentsOf: try self.type.sshHeaderBytes())
        
        wireBytes.append(contentsOf: self.bigEndianByteSize())
        wireBytes.append(contentsOf: self.bytes)
        
        return Data(bytes: wireBytes)
    }
}


extension KeyPair {
    func signAppendingSSHWirePubkeyToPayload(data:Data) throws -> String {
        var dataClone = Data(data)
        let pubkeyWire = try publicKey.wireFormat()
        dataClone.append(contentsOf: pubkeyWire.bigEndianByteSize())
        dataClone.append(pubkeyWire)
        return try sign(data: dataClone).toBase64()
    }
    
}


