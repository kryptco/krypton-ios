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
        return try self.jsonData().seal(key: key).toBase64()
    }
    
    init(key:String, sealed:Sealed) throws {
        guard let sealedData = sealed.fromBase64()
        else {
            throw CryptoError.encoding
        }
        try self.init(key: key, sealedData: sealedData)
    }

    init(key:String, sealedData:Data) throws {
        let jsonData = try sealedData.unseal(key: key)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments)

        guard let json = jsonObject as? JSON
            else {
                throw CryptoError.encoding
        }

        self = try Self.init(json: json)
    }
    
}
