//
//  Pair.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import CoreBluetooth
import Sodium

struct Pairing {

    var name:String
    var uuid: CBUUID
    var queue:QueueName {
        return uuid.uuidString.uppercased()
    }
    var workstationPublicKey:Box.PublicKey
    var symmetricKey:SecretBox.Key

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

    init(json: JSON) throws {
        let pkB64:String = try json ~> "pk"
        guard let workstationPublicKey = pkB64.fromBase64() else {
            throw CryptoError.encoding
        }
        try self.init(name: json ~> "n", workstationPublicKey: workstationPublicKey)
    }

}
