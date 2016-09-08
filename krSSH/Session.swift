//
//  Session.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Session:JSONConvertable {
    var id:String
    var pairing:Pairing
    var created:Date
    
    init(pairing:Pairing) throws {
        self.id = try Data.random(size: 32).toBase64()
        self.pairing = pairing
        self.created = Date()
    }
    
    init(json: JSON) throws {
        id      = try json ~> "id"
        pairing = try Pairing(name: json ~> "name",
                              queue: json ~> "queue",
                              key: KeychainStorage().get(key: id))
        
        created = Date(timeIntervalSince1970: try json ~> "created")
    }
    
    var jsonMap: JSON {
        return ["id": id,
                "name": pairing.name,
                "queue": pairing.queue,
                "created": created.timeIntervalSince1970]
    }
}

struct SignatureLog:JSONConvertable {
    var signature:String
    var date:Date
    
    init(sig:String) {
        signature = sig
        date = Date()
    }
    
    init(json: JSON) throws {
        signature = try json ~> "signature"
        date = Date(timeIntervalSince1970: try json ~> "date")
    }
    
    var jsonMap: JSON {
        return ["signature": signature,
                "date": date.timeIntervalSince1970]
    }
}
