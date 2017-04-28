//
//  KnownHost.swift
//  Kryptonite
//
//  Created by Alex Grinman on 4/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

struct KnownHost {
    var hostName:String
    var publicKey:String
    var dateAdded:Date
    
    init(hostName:String, publicKey:String, dateAdded:Date = Date()) {
        self.hostName  = hostName
        self.publicKey = publicKey
        self.dateAdded = dateAdded
    }
}
