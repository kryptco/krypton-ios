//
//  Session.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

struct Session:Jsonable {
    var id:String
    var pairing:Pairing
    var created:Date

    init(pairing:Pairing) throws {
        self.id = try Data.random(size: 32).toBase64()
        self.pairing = pairing
        self.created = Date()
    }
    
    init(json: Object) throws {
        id      = try json ~> "id"
        
        let workstationPublicKey = try ((try json ~> "workstation_public_key") as String).fromBase64()
        let symmetricKey = try KeychainStorage().get(key: id).fromBase64()
        
        pairing = try Pairing(name: json ~> "name", workstationPublicKey: workstationPublicKey, symmetricKey: symmetricKey)
        
        created = Date(timeIntervalSince1970: try json ~> "created")
    }
    
    var object: Object {
        return ["id": id,
                "name": pairing.name,
                "queue": pairing.queue,
                "created": created.timeIntervalSince1970,
                "workstation_public_key": pairing.workstationPublicKey.toBase64()]
    }

}


