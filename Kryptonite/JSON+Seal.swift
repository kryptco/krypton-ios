//
//  Seal.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

typealias Sealed = Data

extension JsonWritable {
    func seal(key:Key) throws -> Sealed {
        return try self.jsonData().seal(key: key)
    }
}
extension JsonReadable {
    
    init(key:Key, sealedBase64:String) throws {
        try self.init(key: key, sealed: try sealedBase64.fromBase64())
    }

    init(key:Key, sealed:Sealed) throws {
        let json:Object = try JSON.parse(data: sealed.unseal(key: key))
        self = try Self.init(json: json)
    }
    
}
