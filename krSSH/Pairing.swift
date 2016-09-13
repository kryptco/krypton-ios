//
//  Pair.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import CoreBluetooth

struct Pairing:JSONConvertable {
    var name:String
    var queue:QueueName
    var key:String
    
    init(name:String, queue:QueueName, key:String) {
        self.name = name
        self.queue = queue
        self.key = key
    }
    init(json: JSON) throws {
        self.name = try json ~> "n"
        self.queue = try json ~> "q"
        self.key = try json ~> "k"
    }
    
    var jsonMap: JSON {
        return ["n": name, "q": queue, "k": key]
    }

    var bluetoothServiceUUID: CBUUID? {
        guard let key = key.fromBase64() else {
            return nil
        }
        return CBUUID.init(data: key.SHA256.subdata(in: 0 ..< 16))
    }
}
