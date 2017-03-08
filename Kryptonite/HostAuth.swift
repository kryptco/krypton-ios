//
//  HostAuth.swift
//  Kryptonite
//
//  Created by Kevin King on 2/16/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON


struct HostAuth:Jsonable{
    let hostKey: String
    let signature: String
    let hostNames: [String]
    
    public init(json: Object) throws {
        hostKey = try json ~> "host_key"
        signature = try json ~> "signature"
        hostNames = try json ~> "host_names"
    }
    public var object: Object {
        var json:[String:Any] = [:]
        json["host_key"] = hostKey
        json["signature"] = signature
        json["host_names"] = hostNames
        return json
    }
    
    func verify(sessionID: Data) throws -> Bool {
        var keyData = try hostKey.fromBase64()
        let keyBytes = keyData.withUnsafeMutableBytes{ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        }
        var sigData = try signature.fromBase64()
        let sigBytes = sigData.withUnsafeMutableBytes{ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        }
        var sessionIDClone = Data(sessionID)
        let signDataBytes = sessionIDClone.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        })
        let result = kr_verify_signature(keyBytes, keyData.count, sigBytes, sigData.count, signDataBytes, sessionIDClone.count)
        if result == 1 {
            return true
        }
        return false
    }
}
