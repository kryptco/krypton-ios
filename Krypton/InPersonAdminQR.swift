//
//  InPersonAdminQR.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct  AdminQRPayload {
    let lastBlockHash:Data
    let teamPublicKey:SodiumSignPublicKey
    let teamName:String
}

extension AdminQRPayload:Jsonable {
    init(json: Object) throws {
        let object:Object = try json ~> "aqp"
        teamPublicKey = try ((object ~> "tpk") as String).fromBase64().bytes
        lastBlockHash = try ((object ~> "lbh") as String).fromBase64()
        teamName = try object ~> "n"
    }
    
    var object: Object {
        return ["aqp": ["tpk": teamPublicKey.toBase64(),
                        "lbh": lastBlockHash.toBase64(),
                        "n": teamName]]
    }
}
