//
//  Session.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Session {
    var id:String
    var deviceName:String
    var pairing:Pairing
    var lastAccessed:Date
    var logs:[SessionLog]
}

struct SessionLog {
    var signature:String
    var date:String
}
