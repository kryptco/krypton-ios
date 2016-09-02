//
//  Pair.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Pair:JSONConvertable {
    
    var queueName:QueueName
    var symmetricKey:String
    
    init(json: JSON) throws {
        self.queueName = try json ~> "q"
        self.symmetricKey = try json ~> "k"
    }
    
    var jsonMap: JSON {
        return ["q": queueName, "k": symmetricKey]
    }
}
