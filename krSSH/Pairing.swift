//
//  Pair.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import CoreBluetooth

typealias Key = Data
struct Pairing:JSONConvertable {
    var name:String
    var queue:QueueName
    var key:Key
    
    init(name:String, queue:QueueName, key:Key) {
        self.name = name
        self.queue = queue
        self.key = key
    }
    init(json: JSON) throws {
        self.name = try json ~> "n"
        self.queue = try json ~> "q"
        
        let keyB64 : String = try json ~> "k"
        guard let key = keyB64.fromBase64() else {
            throw CryptoError.encoding
        }
        self.key = key
    }
    
    var jsonMap: JSON {
        return ["n": name, "q": queue, "k": key]
    }

    var bluetoothServiceUUID: CBUUID? {

        return CBUUID.init(data: key.SHA256.subdata(in: 0 ..< 16))
    }
}
