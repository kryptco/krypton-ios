//
//  HostAuth.swift
//  Krypton
//
//  Created by Kevin King on 2/16/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct HostMistmatchError:Error, CustomDebugStringConvertible {
    var hostName:String
    var expectedPublicKeys:[Data]
    
    static let prefix = "host public key mismatched for"
    
    var debugDescription:String {
        return "\(HostMistmatchError.prefix) \(hostName)"
    }
    
    // check if an error message is a host mismatch
    // used to indicate what kind of error occured to analytics
    // without exposing the hostName to the analytics service
    static func isMismatchErrorString(err:String) -> Bool {
        return err.contains(HostMistmatchError.prefix)
    }
}


struct HostAuthHasNoHostnames:Error, CustomDebugStringConvertible {
    var debugDescription:String {
        return "No hostnames provided"
    }
}

struct VerifiedUserAndHostAuth:Jsonable {
    let hostname:String
    let user:String
    let uniqueID:String
    
    init(hostname:String, user:String) {
        self.hostname = hostname
        self.user = user
        
        // ensure a unique id by: SHA2(SHA2(hostname)|SHA2(user))
        let hostnameHash = Data(bytes: [UInt8](hostname.utf8)).SHA256
        let userHash = Data(bytes: [UInt8](user.utf8)).SHA256
        self.uniqueID = (hostnameHash + userHash).SHA256.toBase64(true)
    }
    
    init(json: Object) throws {
        try self.init(hostname: json ~> "hostname", user: json ~> "user")
    }
    
    var object: Object {
        return ["hostname": hostname, "user": user]
    }
    
}

struct VerifiedHostAuth:JsonWritable {
    private let hostAuth:HostAuth
    let hostname:String
    
    var hostKey:Data {
        return hostAuth.hostKey
    }
    
    var signature:Data {
        return hostAuth.signature
    }
    
    var object:Object {
        return hostAuth.object
    }
    
    enum Errors:Error {
        case invalidSignature
        case missingHostName
    }
    struct InvalidSignature:Error{}
    struct MissingHostName:Error{}

    init(session:Data, hostAuth:HostAuth) throws {
        guard try hostAuth.verify(session: session) else {
            throw Errors.invalidSignature
        }
        
        guard let hostName = hostAuth.hostNames.first else {
            throw Errors.missingHostName
        }
        
        self.hostname = hostName
        self.hostAuth = hostAuth
    }
}

struct HostAuth:Jsonable{
    let hostKey: Data
    let signature: Data
    let hostNames: [String]
    
    init(hostKey: Data, signature: Data, hostNames: [String]) {
        self.hostKey = hostKey
        self.signature = signature
        self.hostNames = hostNames
    }
    
    public init(json: Object) throws {
        hostKey = try ((json ~> "host_key") as String).fromBase64()
        signature = try ((json ~> "signature") as String).fromBase64()
        hostNames = try json ~> "host_names"
    }
    public var object: Object {
        var json:[String:Any] = [:]
        json["host_key"] = hostKey.toBase64()
        json["signature"] = signature.toBase64()
        json["host_names"] = hostNames
        return json
    }
    
    func verify(session: Data) throws -> Bool {
        var hostKeyData = Data(hostKey)
        let keyBytes = hostKeyData.withUnsafeMutableBytes{ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        }
        
        var sigData = Data(signature)
        let sigBytes = sigData.withUnsafeMutableBytes{ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        }
        var sessionClone = Data(session)
        let signDataBytes = sessionClone.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) in
            return bytes
        })
        let result = kr_verify_signature(keyBytes, hostKeyData.count, sigBytes, sigData.count, signDataBytes, sessionClone.count)
        if result == 1 {
            return true
        }
        return false
    }
}
