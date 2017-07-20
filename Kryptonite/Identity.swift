//
//  Identity.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium
import JSON

struct Identity:Jsonable {
    let id:String
    let email:String
    let team:Team
    
    init(email:String, team:Team) throws {
        try self.init(id: Data.random(size: 32).toBase64(), email: email, team: team)
    }
    
    private init(id:String, email:String, team:Team) {
        self.id = id
        self.email = email
        self.team = team
    }
    
    init(json: Object) throws {
        try self.init(id: json ~> "id", email: json ~> "email", team: Team(json: json ~> "team"))
    }
    
    var object: Object {
        return ["id": id, "email": email, "team": team.object]
    }
}

struct Team:Jsonable {
    let name:String
    let publicKey:SodiumPublicKey
    
    init(name:String, publicKey:SodiumPublicKey) {
        self.name = name
        self.publicKey = publicKey
    }
    
    init(json: Object) throws {
        try self.init(name: json ~> "name", publicKey: SodiumPublicKey(((json ~> "public_key") as String).fromBase64()))
    }
    
    var object: Object {
        return ["name": name, "public_key": publicKey.toBase64()]
    }
}

