//
//  Request.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

struct Request:Jsonable {
    
    var id:String
    var unixSeconds:Int
    var sendACK:Bool
    var version:Version?
    var sign:SignRequest?
    var list:ListRequest?
    var me:MeRequest?
    var unpair:UnpairRequest?
    
    init(json: Object) throws {
        self.id = try json ~> "request_id"
        self.unixSeconds = try json ~> "unix_seconds"
        self.sendACK = (try? json ~> "a") ?? false

        if let json:Object = try? json ~> "sign_request" {
            self.sign = try SignRequest(json: json)
        }
        
        if let json:Object = try? json ~> "list_request" {
            self.list = try ListRequest(json: json)
        }
        
        if let json:Object = try? json ~> "me_request" {
            self.me = try MeRequest(json: json)
        }

        if let json:Object = try? json ~> "unpair_request" {
            self.unpair = try UnpairRequest(json: json)
        }

        if let verString:String = try? json ~> "v" {
            self.version = Version(string: verString)
        }
    }
    
    var object:Object {
        var json:[String:Any] = [:]
        json["request_id"] = id
        json["unix_seconds"] = unixSeconds
        json["a"] = sendACK

        if let s = sign {
            json["sign_request"] = s.object
        }
        
        if let l = list {
            json["list_request"] = l.object
        }
        
        if let m = me {
            json["me_request"] = m.object
        }

        if let u = unpair {
            json["unpair_request"] = u.object
        }

        return json
    }

    func isNoOp() -> Bool {
        return sign == nil && list == nil && me == nil && unpair == nil
    }
}

//MARK: Requests

// Sign

struct SignRequest:Jsonable {
    var digest:String
    var fingerprint:String
    var command:String?
    var hostAuth:HostAuth?

    init(json: Object) throws {
        self.digest = try json ~> "digest"
        self.fingerprint = try json ~> "public_key_fingerprint"
        if let command:String = try? json ~> "command" {
            self.command = command
        }
        if let json:Object = try? json ~> "host_auth" {
            self.hostAuth = try HostAuth(json: json)
        }
    }
    
    var object: Object {
        var json:[String:Any] = ["digest": digest,
                                "public_key_fingerprint": fingerprint]
        
        if let command = command {
            json["command"] = command
        }
        
        return json
    }

    var sshSessionID:Data? {
        guard let digestBytes = try? digest.fromBase64(),
            digestBytes.count >= 36 else {
            return nil
        }
        return digestBytes.subdata(in: 4..<36)
    }

    var user:String? {
        guard let digestBytes = try? digest.fromBase64(),
            digestBytes.count >= 38 else {
            return nil
        }
        //  user field starts at bytes[37]
        let userLen = Int32(bigEndianBytes: [UInt8](digestBytes.subdata(in: 37..<41)))
        if userLen > 0 && digestBytes.count > userLen - 41 {
            let userCStringBytes = digestBytes.subdata(in: 41..<Int(41+userLen))
            let user = String(bytes: userCStringBytes, encoding: .utf8)
            log("userLen \(userLen) user \(user)")
            return user
        }
        return nil
    }

    var display:String {
        let host = hostAuth?.hostNames.first ?? "unknown host"
        guard let user = user else {
            return host
        }
        return "\(user)@\(host)"
    }

}


// List
struct ListRequest:Jsonable {
    init(json: Object) throws {}
    var object: Object {return [:]}
}

// Me
struct MeRequest:Jsonable {
    init(json: Object) throws {}
    var object: Object {return [:]}
}

// Unpair
struct UnpairRequest:Jsonable {
    init(json: Object) throws {}
    var object: Object {return [:]}
}





