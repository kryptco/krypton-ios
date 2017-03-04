//
//  Pair.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreBluetooth
import Sodium
import JSON

typealias QueueName = String

struct Pairing:JsonReadable {

    var name:String
    var uuid: CBUUID
    var queue:String {
        return uuid.uuidString.uppercased()
    }
    var workstationPublicKey:Box.PublicKey
    var keyPair:Box.KeyPair
    
    var displayName:String {
        return name.removeDotLocal()
    }
    
    init(name: String, workstationPublicKey:Box.PublicKey) throws {
        guard let keyPair = try KRSodium.shared().box.keyPair() else {
            throw CryptoError.generate(KeyType.Ed25519, nil)
        }
        
        try self.init(name: name, workstationPublicKey: workstationPublicKey, keyPair: keyPair)
    }

    init(name: String, workstationPublicKey:Box.PublicKey, keyPair:Box.KeyPair) throws {
        self.workstationPublicKey = workstationPublicKey
        self.keyPair = keyPair
        self.name = name
        self.uuid = CBUUID.init(data: workstationPublicKey.SHA256.subdata(in: 0 ..< 16))
    }

    init(json: Object) throws {
        let pkB64:String = try json ~> "pk"
        let workstationPublicKey = try pkB64.fromBase64()
                
        try self.init(name: json ~> "n", workstationPublicKey: workstationPublicKey)
    }

}

