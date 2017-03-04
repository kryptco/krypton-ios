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
    var version:Version?
    
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

        pairing = try Pairing(name: json ~> "name", workstationPublicKey: workstationPublicKey, keyPair: Box.KeyPair(publicKey: publicKey, secretKey: privateKey))
        
        if let v:String = try json ~> "v" {
            version = Version(string: v)
        }

        created = Date(timeIntervalSince1970: try json ~> "created")
    }
    
    var object: Object {
        var objectMap = ["id": id,
                         "name": pairing.name,
                         "queue": pairing.queue,
                         "created": created.timeIntervalSince1970,
                         "workstation_public_key": pairing.workstationPublicKey.toBase64()] as [String : Any]
        
        if let ver = version {
            objectMap["v"] = ver
        }
        
        return objectMap
    }

}




