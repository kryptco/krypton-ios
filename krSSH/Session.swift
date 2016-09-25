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
        
        let workstationPublicKey = try ((try json ~> "workstationPublicKey") as String).fromBase64()
        let symmetricKey = try KeychainStorage().get(key: id).fromBase64()
        
        pairing = try Pairing(name: json ~> "name", workstationPublicKey: workstationPublicKey, symmetricKey: symmetricKey)
        
        created = Date(timeIntervalSince1970: try json ~> "created")
    }
    
    var jsonMap: JSON {
        return ["id": id,
                "name": pairing.name,
                "queue": pairing.queue,
                "created": created.timeIntervalSince1970,
                "workstationPublicKey": pairing.workstationPublicKey.toBase64()]
    }

}


