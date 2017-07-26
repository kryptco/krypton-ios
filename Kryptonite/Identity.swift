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

/**
    Map an identity to a key pair using it's tag
 */
protocol IdentityKeyPointer {
    var tag:String { get }
}


/**
    The default, 'personal', identity
 */
struct DefaultIdentity:IdentityKeyPointer {
    var tag:String {
        return "me"
    }
}



struct Identity:Jsonable, IdentityKeyPointer {
    let id:String
    let email:String
    let team:Team
    let keyPair:SodiumKeyPair
    let usesDefaultKey:Bool
    
    var tag:String {
        if usesDefaultKey {
            return DefaultIdentity().tag
        }
        
        return "me_\(id)"
    }

    /**
        Create a new identity with an email for use with `team`
     */
    init(email:String, team:Team, usesDefaultKey:Bool) throws {
        let id = try Data.random(size: 32).toBase64()
        guard let keyPair = try KRSodium.shared().sign.keyPair() else {
            throw CryptoError.generate(KeyType.Ed25519, nil)
        }
        
        self.init(id: id, email: email, team: team, keyPair: keyPair, usesDefaultKey: usesDefaultKey)
    }
    
    private init(id:String, email:String, team:Team, keyPair:SodiumKeyPair, usesDefaultKey:Bool) {
        self.id = id
        self.email = email
        self.team = team
        self.keyPair = keyPair
        self.usesDefaultKey = usesDefaultKey
    }
    
    init(json: Object) throws {
        try self.init(id: json ~> "id",
                      email: json ~> "email",
                      team: Team(json: json ~> "team"),
                      keyPair: SodiumKeyPair(publicKey: ((json ~> "pk") as String).fromBase64(),
                                             secretKey: ((json ~> "sk") as String).fromBase64()),
                      usesDefaultKey: json ~> "uses_default_key")
    }
    
    var object: Object {
        return ["id": id,
                "email": email,
                "team": team.object,
                "pk": keyPair.publicKey.toBase64(),
                "sk": keyPair.secretKey.toBase64(),
                "uses_default_key": usesDefaultKey]
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

