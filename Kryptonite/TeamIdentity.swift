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

struct TeamIdentity:Jsonable {
    let id:String
    let email:String
    let team:Team
    let keyPair:SodiumKeyPair
    
    /**
        Create a new identity with an email for use with `team`
     */
    init(email:String, team:Team) throws {
        let id = try Data.random(size: 32).toBase64()
        guard let keyPair = try KRSodium.shared().sign.keyPair() else {
            throw CryptoError.generate(KeyType.Ed25519, nil)
        }
        
        self.init(id: id, email: email, team: team, keyPair: keyPair)
    }
    
    private init(id:String, email:String, team:Team, keyPair:SodiumKeyPair) {
        self.id = id
        self.email = email
        self.team = team
        self.keyPair = keyPair
    }
    
    init(json: Object) throws {
        try self.init(id: json ~> "id",
                      email: json ~> "email",
                      team: Team(json: json ~> "team"),
                      keyPair: SodiumKeyPair(publicKey: ((json ~> "pk") as String).fromBase64(),
                                             secretKey: ((json ~> "sk") as String).fromBase64()))
    }
    
    var object: Object {
        return ["id": id,
                "email": email,
                "team": team.object,
                "pk": keyPair.publicKey.toBase64(),
                "sk": keyPair.secretKey.toBase64()]
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

