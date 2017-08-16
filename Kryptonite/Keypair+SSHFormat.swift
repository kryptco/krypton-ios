//
//  SSHFormat.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation
import Security
import Sodium

//MARK: SSH Public Key + Wire Format

protocol SSHPublicKey {
    func wireFormat() throws -> Data
}

struct UnknownSSHKeyWireFormat:Error {}
struct BadSSHKeyWireFormat:Error {}

extension PublicKey {
    func wireFormat() throws -> Data {
        guard let sshKey = self as? SSHPublicKey
        else {
            throw UnknownSSHKeyWireFormat()
        }
        
        return try sshKey.wireFormat()
    }
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
    func toAuthorized() throws -> SSHAuthorizedFormat {
        let dataBytes = self.bytes

        guard dataBytes.count >= 4 else {
            throw BadSSHKeyWireFormat()
        }
        
        
        let headerLength = Int(UInt32(bigEndianBytes: [UInt8](dataBytes[0 ..< 4])))
        
        guard dataBytes.count >= 4 + headerLength else {
            throw BadSSHKeyWireFormat()
        }
        
        let header = try Data(bytes: [UInt8](dataBytes[4 ..< 4 + headerLength])).utf8String()
        
        return "\(header) \(self.toBase64())"
    }
    
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
extension RSAPublicKey:SSHPublicKey {
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

extension Sign.PublicKey:SSHPublicKey {
    func wireFormat() throws -> Data {
        // ssh-wire-encoding(ssh-ed25519, len pub key, pub key)
        
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x0B]
        wireBytes.append(contentsOf: try self.type.sshHeaderBytes())
        
        wireBytes.append(contentsOf: self.bigEndianByteSize())
        wireBytes.append(contentsOf: self.bytes)
        
        return Data(bytes: wireBytes)
    }
}

// MARK: SSH Digest Type
struct UnsupportedSSHDigestAlgorithm:Error {}

extension DigestType {
    
    /**
     Select a signature digest algorithm based on `algorithmName` found in
     SSH_MSG_USERAUTH_REQUEST. 
     
     2.1.0 adds support for rsa sha256/512 signatures per: https://tools.ietf.org/html/draft-rsa-dsa-sha2-256-03
     */
    init(algorithmName:String) throws {
        switch algorithmName {
            case KeyType.RSA.sshHeader():
                self = .sha1
            case "rsa-sha2-256":
                self = .sha256
            case "rsa-sha2-512":
                self = .sha512
            case KeyType.Ed25519.sshHeader():
                self = .ed25519
            default:
                throw UnsupportedSSHDigestAlgorithm()
        }
    }
    
    
    /**
        Modify digest type based on a request's version for
        backwards compatibility. Note that before 2.1.0, sha1 was 
        always used for RSA signatures.
     
        OpenSSH still accepts it even though the server asks for a different digest algorithm.
        Furthermore OpenSSH releases less than 7.2 (and a bug introduced in OpenSSH 7.4) still
        use sha1 for RSA signatures (read: many servers still ask for sha1 signatures).
        The current release of OpenSSH resolves this: https://www.openssh.com/txt/release-7.5
     
        Since the session (in the data payload being signed) is a sha2 hash, the risk of sha1
        is smaller, but still should be avoided.

        TODO: remove this after majority of users >2.1.0
     */
    func based(on version:Version) -> DigestType {
        
        let introduced = Properties.Compatibility.rsaSha256Sha512Support
        
        switch self {
        case .sha256 where version < introduced,
             .sha512 where version < introduced:
            return .sha1
        default:
            return self
        }
    }
}

// MARK: SSH Signature Format
extension KeyPair {
    func signAppendingSSHWirePubkeyToPayload(data:Data, digestType:DigestType) throws -> String {
        var dataClone = Data(data)
        let pubkeyWire = try publicKey.wireFormat()
        dataClone.append(contentsOf: pubkeyWire.bigEndianByteSize())
        dataClone.append(pubkeyWire)
        return try sign(data: dataClone, digestType: digestType).toBase64()
    }
    
}


