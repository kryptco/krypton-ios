//
//  SignatureLog.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

struct SignatureLog {
    var session:String
    var signature:String
    var date:Date
    var displayName:String
    var hostAuth:String
    
    init(session:String, hostAuth:HostAuth?, signature:String, displayName:String, date:Date = Date()) {
        
        var theHostAuth:String
        if let host = hostAuth, let hostJson = try? host.jsonString(prettyPrinted: false) {
            theHostAuth = hostJson
        } else {
            theHostAuth = "unknown"
        }
        
        self.init(session: session, hostAuth: theHostAuth, signature: signature, displayName: displayName, date: date)
    }
    
    init(session:String, hostAuth:String, signature:String, displayName:String, date:Date = Date()) {
        self.session = session  
        self.hostAuth = hostAuth
        self.signature = signature
        self.displayName = displayName
        self.date = date
    }
}
