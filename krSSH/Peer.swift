//
//  Peer.swift
//  krSSH
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Peer {
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
}

func ==(lp:Peer, rp:Peer) -> Bool {
    return  lp.email == rp.email &&
            lp.fingerprint == rp.fingerprint &&
            lp.publicKey == rp.publicKey
    
}
