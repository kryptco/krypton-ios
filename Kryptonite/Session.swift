//
//  Session.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON
import Sodium

struct Session:Jsonable {
    var id:String
    var pairing:Pairing
    var created:Date
    
    enum KeychainKey:String {
        case pub = "public"
        case priv = "private"
        
        func tag(for id:String) -> String {
            return "\(id)_\(self.rawValue)"
        }
    }
    
    init(pairing:Pairing) throws {
        self.id = try Data.random(size: 32).toBase64()
        self.pairing = pairing
        self.created = Date()
    }
    
    init(json: Object) throws {
        id  = try json ~> "id"
        
        let workstationPublicKey = try ((try json ~> "workstation_public_key") as String).fromBase64()
        
        let publicKey = try KeychainStorage().get(key: KeychainKey.pub.tag(for: id)).fromBase64()
        let privateKey = try KeychainStorage().get(key: KeychainKey.priv.tag(for: id)).fromBase64()

        var version:Version?
        if let verString:String = try? json ~> "version" {
            version = try Version(string: verString)
        }

        pairing = try Pairing(name: json ~> "name", workstationPublicKey: workstationPublicKey, keyPair: Box.KeyPair(publicKey: publicKey, secretKey: privateKey), version: version)
        

        created = Date(timeIntervalSince1970: try json ~> "created")
    }
    
    var object: Object {
        var objectMap:[String : Any] = ["id": id,
                         "name": pairing.name,
                         "queue": pairing.queue,
                         "created": created.timeIntervalSince1970,
                         "workstation_public_key": pairing.workstationPublicKey.toBase64()]
        
        if let ver = pairing.version {
            objectMap["version"] = ver.string
        }
        
        return objectMap
    }

}




