//
//  KnownHost.swift
//  Kryptonite
//
//  Created by Alex Grinman on 4/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct SSHHostKey:Jsonable {
    let host:String
    let publicKey:SSHWireFormat
    
    init(host:String, publicKey:SSHWireFormat) {
        self.host = host
        self.publicKey = publicKey
    }
    
    init(json: Object) throws {
        try self.init(host: json ~> "host",
                      publicKey: ((json ~> "public_key") as String).fromBase64())
    }
    
    var object: Object {
        return ["host": host,
                "public_key": publicKey.toBase64()]
    }
    
    var displayPublicKey:String {
        return (try? publicKey.toAuthorized()) ?? publicKey.toBase64()
    }
    
    func knownHost() throws -> KnownHost {
        return try KnownHost(hostName: host, publicKey: publicKey.toAuthorized())
    }
}

struct KnownHost {
    var hostName:String
    var publicKey:SSHAuthorizedFormat
    var dateAdded:Date
    
    init(hostName:String, publicKey:SSHAuthorizedFormat, dateAdded:Date = Date()) {
        self.hostName  = hostName
        self.publicKey = publicKey
        self.dateAdded = dateAdded
    }
    
    func sshHostKey() throws -> SSHHostKey {
        return try SSHHostKey(host: hostName, publicKey: publicKey.toWire())
    }
}

func ==(l:KnownHost, r:KnownHost) -> Bool {
    return l.hostName == r.hostName && l.publicKey == r.publicKey
}
