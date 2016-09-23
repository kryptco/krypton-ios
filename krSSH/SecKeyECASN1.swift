//
//  SecKeyECASN1.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation


// Software (1) License

//MARK: Elliptic Curve ASN.1 Import/Export Headers
typealias ECASN1Header = (curveLength:Int, headerLength:Int, header:[UInt8])

private let Secp256r1:ECASN1Header = (256, 26, [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00])

private let Secp384r1:ECASN1Header = (384, 23, [0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00])

private let Secp521r1:ECASN1Header = (521, 25, [0x30, 0x81, 0x9B, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23, 0x03, 0x81, 0x86, 0x00])

extension PublicKey {
    func exportSecpData() throws -> Data {
        
        var publicKeyData:Data
        
        do {
            publicKeyData = try export() as Data
        } catch(let e) {
            throw e
        }
        
        let keySize = SecKeyGetBlockSize(key)*8
        
        let curveOIDHeader: [UInt8]
        let curveOIDHeaderLen: Int
        switch keySize {
        case Secp256r1.curveLength:
            curveOIDHeader = Secp256r1.header
            curveOIDHeaderLen = Secp256r1.headerLength
        case Secp384r1.curveLength:
            curveOIDHeader = Secp384r1.header
            curveOIDHeaderLen = Secp384r1.headerLength
        case Secp521r1.curveLength:
            curveOIDHeader = Secp521r1.header
            curveOIDHeaderLen = Secp521r1.headerLength
        default:
            throw CryptoError.export(nil)
        }
        
        let data = NSMutableData(bytes: curveOIDHeader, length: curveOIDHeaderLen)
        data.append(publicKeyData)
        return (data as Data)
    }
    
    
    func exportSecp() throws -> String {
        return try exportSecpData().toBase64()
    }
    
    
    func wireFormat() throws -> String {
        let publicKeyData = try export() as Data
        
        
        guard   let keyTypeBytes = "ecdsa-sha2-nistp256".data(using: String.Encoding.utf8)?.bytes,
                let nistID = "nistp256".data(using: String.Encoding.utf8)?.bytes
        else {
            throw CryptoError.encoding
        }
     
        var wireBytes:[UInt8] = [0x00, 0x00, 0x00, 0x13]
        wireBytes.append(contentsOf: keyTypeBytes)
        wireBytes.append(contentsOf: [0x00, 0x00, 0x00, 0x08])

        wireBytes.append(contentsOf: nistID)
        
        let sizeBytes = stride(from: 24, through: 0, by: -8).map {
            UInt8(truncatingBitPattern: UInt32(publicKeyData.count).littleEndian >> UInt32($0))
        }
        
        wireBytes.append(contentsOf: sizeBytes)
        wireBytes.append(contentsOf: publicKeyData.bytes)
        
        return "ecdsa-sha2-nistp256 \(Data(bytes: wireBytes).toBase64())"        
    }
    
}


extension String {
    func fingerprint() throws -> Data {
        guard let data = self.fromBase64() else {
            throw CryptoError.encoding
        }
        
        return data.SHA256
    }
}


