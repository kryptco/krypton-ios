//
//  SignatureLog.swift
//  krSSH
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct SignatureLog {
    var session:String
    var signature:String
    var date:Date
    
    init(session:String, signature:String, date:Date = Date()) {
        self.session = session
        self.signature = signature
        self.date = date
    }
    

}
