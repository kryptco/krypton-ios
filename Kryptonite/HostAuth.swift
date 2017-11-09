//
//  HostAuth.swift
//  Kryptonite
//
//  Created by Kevin King on 2/16/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct HostAuthHasNoHostnames:Error, CustomDebugStringConvertible {
    var debugDescription:String {
        return "No hostnames provided"
    }
}

struct VerifiedUserAndHostAuth {
    let hostAuth:VerifiedHostAuth
    let user:String
    let uniqueID:String
    
    init(hostAuth:VerifiedHostAuth, user:String) {
        self.hostAuth = hostAuth
        self.user = user
        
        // ensure a unique id by: SHA2(SHA2(hostname)|SHA2(user))
        let hostnameHash = Data(bytes: [UInt8](hostAuth.hostname.utf8)).SHA256
        let userHash = Data(bytes: [UInt8](user.utf8)).SHA256
        self.uniqueID = (hostnameHash + userHash).SHA256.toBase64(true)
    }
}

struct VerifiedHostAuth:JsonWritable {
    private let hostAuth:HostAuth
    let hostname:String
    
    var hostKey:String {
        return hostAuth.hostKey
    }
    
    var signature:String {
        return hostAuth.signature
    }
    
    var object:Object {
        return hostAuth.object
    }
    
    struct InvalidSignature:Error{}

    init(session:Data, hostAuth:HostAuth) throws {
        guard try hostAuth.verify(session: session) else {
            throw InvalidSignature()
        }
        
        guard let hostname = hostAuth.hostNames.first else {
            throw HostAuthHasNoHostnames()
        }
        
        self.hostname = hostname
        self.hostAuth = hostAuth
    }
}

struct HostAuth:Jsonable{
    let hostKey: String
    let signature: String
    let hostNames: [String]
    
    init(hostKey: String, signature: String, hostNames: [String]) throws {
        self.hostKey = hostKey
        self.signature = signature
        self.hostNames = hostNames
    }
    
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
    
    func verify(session: Data) throws -> Bool {
        var keyData = try hostKey.fromBase64()
        let keyBytes = keyData.withUnsafeMutableBytes{ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        }
        var sigData = try signature.fromBase64()
        let sigBytes = sigData.withUnsafeMutableBytes{ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        }
        var sessionClone = Data(session)
        let signDataBytes = sessionClone.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        })
        let result = kr_verify_signature(keyBytes, keyData.count, sigBytes, sigData.count, signDataBytes, sessionClone.count)
        if result == 1 {
            return true
        }
        return false
    }
}
