//
//  SecKeyECASN1.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
//

import Foundation


// Software (1) License

//MARK: Elliptic Curve ASN.1 Import/Export Headers
typealias ECASN1Header = (curveLength:Int, headerLength:Int, header:[UInt8])

private let Secp256r1:ECASN1Header = (256, 26, [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00])

private let Secp384r1:ECASN1Header = (384, 23, [0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00])

private let Secp521r1:ECASN1Header = (521, 25, [0x30, 0x81, 0x9B, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23, 0x03, 0x81, 0x86, 0x00])

extension PublicKey {
    func exportSecp() throws -> String {
        
        var publicKeyData:NSData
        
        do {
            publicKeyData = try self.export()
        } catch(let e) {
            throw e
        }
        
        let keySize = SecKeyGetBlockSize(key)
        
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
            throw CryptoError.Export(nil)
        }
        
        let data = NSMutableData(bytes: curveOIDHeader, length: curveOIDHeaderLen)
        data.appendData(publicKeyData)
        return data.toBase64()
    }
}


