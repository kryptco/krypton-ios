//
//  SecKeyECASN1.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
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
    func authorizedFormat() throws -> SSHAuthorizedFormat {
        return try self.wireFormat().toAuthorized()
    }
    
    func fingerprint() throws -> Data {
        return try self.wireFormat().fingerprint()
    }
}

extension Int32 {
    init(bigEndianBytes: [UInt8]) {
        if bigEndianBytes.count < 4 {
            self.init(0)
            return
        }
        var val : Int32 = 0
        for i in Int32(0)..<4 {
            val += Int32(bigEndianBytes[Int(i)]) << ((3 - i) * 8)
        }
        self.init(val)
    }
}
