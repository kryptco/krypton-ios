//
//  Pair.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Pairing:JSONConvertable {
    
    var queue:QueueName
    var key:String
    
    init(json: JSON) throws {
        self.queue = try json ~> "q"
        self.key = try json ~> "k"
    }
    
    var jsonMap: JSON {
        return ["q": queue, "k": key]
    }
}
