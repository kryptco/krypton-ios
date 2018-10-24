//
//  InPersonMemberQR.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct  NewMemberQRPayload {
    let publicKey:SodiumSignPublicKey
    let email:String
}

extension NewMemberQRPayload:Jsonable {
    init(json: Object) throws {
        let object:Object = try json ~> "mqp"
        publicKey = try ((object ~> "pk") as String).fromBase64().bytes
        email = try object ~> "e"
    }
    
    var object: Object {
        return  ["mqp": ["pk": publicKey.toBase64(),
                                       "e": email]
        ]
    }
}
