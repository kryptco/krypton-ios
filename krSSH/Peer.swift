//
//  Peer.swift
//  krSSH
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

private let KrUnknownEmailValue = "unknown"

struct Peer:JSONConvertable {
    var email:String
    var fingerprint:String
    var publicKey:String
    var dateAdded:Date

    
    init(email:String, fingerprint:String, publicKey:String, date:Date = Date()) {
        self.email = email
        self.fingerprint = fingerprint
        self.publicKey = publicKey
        self.dateAdded = date
    }
    
    init(json:JSON) throws {
        
        let publicKey:String = try json ~> "public_key_der"
        let fingerprint = try publicKey.fingerprint().toBase64()
        let email:String? = try json ~> "email"
        
        self.publicKey = publicKey
        self.email = email ?? KrUnknownEmailValue
        self.dateAdded = Date()
        self.fingerprint = fingerprint
    }
    
    var jsonMap:JSON {
        return ["email": email, "public_key_der": publicKey]
    }
    
    var hasEmail:Bool {
        return email != KrUnknownEmailValue
    }
}

func ==(lp:Peer, rp:Peer) -> Bool {
    return  lp.email == rp.email &&
            lp.fingerprint == rp.fingerprint &&
            lp.publicKey == rp.publicKey
    
}
