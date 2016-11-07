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

struct Pairing:JsonReadable {

    var name:String
    var uuid: CBUUID
    var queue:QueueName {
        return uuid.uuidString.uppercased()
    }
    var workstationPublicKey:Box.PublicKey
    var symmetricKey:SecretBox.Key
    
    var displayName:String {
        return name.removeDotLocal()
    }

    init(name: String, workstationPublicKey:Box.PublicKey) throws {
        let symmetricKey = try Data.random(size: KRSodium.shared().secretBox.KeyBytes)
        try self.init(name: name, workstationPublicKey: workstationPublicKey, symmetricKey: symmetricKey)
    }

    init(name: String, workstationPublicKey:Box.PublicKey, symmetricKey:SecretBox.Key) throws {
        self.workstationPublicKey = workstationPublicKey
        self.symmetricKey = symmetricKey
        self.name = name
        self.uuid = CBUUID.init(data: workstationPublicKey.SHA256.subdata(in: 0 ..< 16))
    }

    init(json: Object) throws {
        let pkB64:String = try json ~> "pk"
        let workstationPublicKey = try pkB64.fromBase64()
        try self.init(name: json ~> "n", workstationPublicKey: workstationPublicKey)
    }

}

