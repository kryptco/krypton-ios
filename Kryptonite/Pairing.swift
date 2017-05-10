//
//  Pair.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import Sodium
import JSON

typealias QueueName = String

struct Pairing:JsonReadable {

    var name:String
    var uuid: UUID
    var queue:String {
        return uuid.uuidString.uppercased()
    }
    var workstationPublicKey:Box.PublicKey
    var keyPair:Box.KeyPair
    
    var displayName:String {
        return name.removeDotLocal()
    }
    
    var version:Version?

    
    init(name: String, workstationPublicKey:Box.PublicKey, version:Version? = nil) throws {
        guard let keyPair = try KRSodium.shared().box.keyPair() else {
            throw CryptoError.generate(KeyType.Ed25519, nil)
        }
        
        try self.init(name: name, workstationPublicKey: workstationPublicKey, keyPair: keyPair, version: version)
    }

    init(name: String, workstationPublicKey:Box.PublicKey, keyPair:Box.KeyPair, version:Version? = nil) throws {
        self.workstationPublicKey = workstationPublicKey
        self.keyPair = keyPair
        self.name = name
        self.uuid = NSUUID(uuidBytes: workstationPublicKey.SHA256.subdata(in: 0 ..< 16).bytes) as UUID
        self.version = version
    }

    init(json: Object) throws {
        let pkB64:String = try json ~> "pk"
        let workstationPublicKey = try pkB64.fromBase64()
        
        var version:Version?
        if let v:String = try? json ~> "v" {
            version = try Version(string: v)
        }
        
        try self.init(name: json ~> "n", workstationPublicKey: workstationPublicKey, version:version)
    }

}

