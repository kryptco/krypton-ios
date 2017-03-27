//
//  SignatureLog.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

struct SignatureLog:JsonWritable {
    var session:String
    var digest:String
    var signature:String
    var date:Date
    var displayName:String
    var hostAuth:String
    
    init(session:String, digest:String, hostAuth:HostAuth?, signature:String, displayName:String, date:Date = Date()) {
        
        var theHostAuth:String
        if let host = hostAuth, let hostJson = try? host.jsonString() {
            theHostAuth = hostJson
        } else {
            theHostAuth = "unknown"
        }
        
        self.init(session: session, digest: digest, hostAuth: theHostAuth, signature: signature, displayName: displayName, date: date)
    }
    
    init(session:String, digest:String, hostAuth:String, signature:String, displayName:String, date:Date = Date()) {
        self.session = session  
        self.digest = digest
        self.hostAuth = hostAuth
        self.signature = signature
        self.displayName = displayName
        self.date = date
    }
    
    var object:Object {
        return  ["request": self.displayName,
                 "host_auth": hostAuth,
                 "signature": signature,
                 "date": date.toLongTimeString()]
    }
    
}
