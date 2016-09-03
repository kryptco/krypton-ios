//
//  Seal.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


typealias Sealed = String
extension JSONConvertable {
    
    func seal(key:String) throws -> Sealed {
        guard let keyData = key.fromBase64()
        else {
            throw CryptoError.encoding
        }
        
        guard let nonce = NARandom.randomData(UInt(NASecretBoxNonceSize)) else {
            throw CryptoError.random
        }

        let message = try self.jsonData()
        
        let ciphertext = try NASecretBox().encrypt(message, nonce: nonce, key: keyData)
        
        var nonceAndCiphertext = Data(capacity: nonce.count + ciphertext.count)
        nonceAndCiphertext.append(nonce)
        nonceAndCiphertext.append(ciphertext)
        
        return nonceAndCiphertext.toBase64()
    }
    
    init(key:String, sealed:Sealed) throws {
        guard
            let keyData = key.fromBase64(),
            let nonceAndCiphertext = sealed.fromBase64(),
            let nonceIndex = nonceAndCiphertext.index(of: UInt8(NASecretBoxNonceSize))
        else {
            throw CryptoError.encoding
        }
        
        let nonce = nonceAndCiphertext.subdata(in: nonceAndCiphertext.startIndex ..< nonceIndex)
        let ciphertext = nonceAndCiphertext.subdata(in: nonceIndex ..< nonceAndCiphertext.endIndex)

        let jsonData = try NASecretBox().decrypt(ciphertext, nonce: nonce, key: keyData)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments)
        
        guard let json = jsonObject as? JSON
        else {
            throw CryptoError.encoding
        }
        
        self = try Self.init(json: json)
    }
    
}
