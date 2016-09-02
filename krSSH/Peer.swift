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
    
    init?(json:[String:AnyObject]) {
        guard   let publicKey = json["public_key"] as? String,
                let fingerprint = publicKey.secp256Fingerprint?.toBase64()
        else {
            return nil
        }
        
        self.publicKey = publicKey
        self.email = (json["email"] as? String) ?? KrUnknownEmailValue
        self.dateAdded = Date()
        self.fingerprint = fingerprint
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
