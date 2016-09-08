//
//  Pair.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

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
}
