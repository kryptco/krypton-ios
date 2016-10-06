//
//  Peer.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

private let KrUnknownEmailValue = "unknown"

struct Peer:JSONConvertable {
    var email:String
    var fingerprint:Data
    var publicKey:SSHWireFormat
    var dateAdded:Date

    
    init(email:String, fingerprint:Data, publicKey:SSHWireFormat, date:Date = Date()) {
        self.email = email
        self.fingerprint = fingerprint
        self.publicKey = publicKey
        self.dateAdded = date
    }
    
    init(json:JSON) throws {
        
        let publicKeyBase64:String = try json ~> "rsa_public_key_wire"
        self.publicKey = try publicKeyBase64.fromBase64()
        self.fingerprint = self.publicKey.fingerprint()
        
        let email:String? = try json ~> "email"
        self.email = email ?? KrUnknownEmailValue
        
        let epoch:Double? = try? json ~> "date"
        if  let epoch = epoch {
            self.dateAdded = Date(timeIntervalSince1970: epoch)
        } else {
            self.dateAdded = Date()
        }
    }
    
    var jsonMap:JSON {
        return ["email": email, "rsa_public_key_wire": publicKey.toBase64()]
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
