//
//  Seal.swift
//  Krypton
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON
import Sodium

typealias Sealed = Data

extension JsonWritable {
    func seal(to pairing:Pairing) throws -> Sealed {
        
        let sealedResult:Bytes? = try KRSodium.instance().box.seal(message: self.jsonData().bytes, recipientPublicKey: pairing.workstationPublicKey, senderSecretKey: pairing.keyPair.secretKey)
        
        guard let sealed = sealedResult else {
            throw CryptoError.encrypt
        }
        
        return sealed.data
    }
}

extension JsonReadable {
    
    init(from pairing:Pairing , sealedBase64:String) throws {
        try self.init(from: pairing, sealed: try sealedBase64.fromBase64())
    }

    init(from pairing:Pairing, sealed:Sealed) throws {
        let unsealedResult = KRSodium.instance().box.open(nonceAndAuthenticatedCipherText: sealed.bytes, senderPublicKey: pairing.workstationPublicKey, recipientSecretKey: pairing.keyPair.secretKey)
        
        guard let unsealed = unsealedResult else {
            throw CryptoError.decrypt
        }
        
        let json:Object = try JSON.parse(data: unsealed.data)
        self = try Self.init(json: json)
    }
    
}
