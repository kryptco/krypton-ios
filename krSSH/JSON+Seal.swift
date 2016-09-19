//
//  Seal.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


typealias Sealed = Data
extension JSONConvertable {
    
    func seal(key:Key) throws -> Sealed {
        return try self.jsonData().seal(key: key)
    }
    
    init(key:Key, sealedBase64:String) throws {
        guard let sealedData = sealedBase64.fromBase64()
        else {
            throw CryptoError.encoding
        }
        try self.init(key: key, sealed: sealedData)
    }

    init(key:Key, sealed:Sealed) throws {
        let jsonData = try sealed.unseal(key: key)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments)

        guard let json = jsonObject as? JSON
            else {
                throw CryptoError.encoding
        }

        self = try Self.init(json: json)
    }
    
}
