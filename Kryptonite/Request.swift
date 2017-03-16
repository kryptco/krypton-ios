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
    var me:MeRequest?
    var unpair:UnpairRequest?
    
    init(json: Object) throws {
        self.id = try json ~> "request_id"
        self.unixSeconds = try json ~> "unix_seconds"
        self.sendACK = (try? json ~> "a") ?? false

        if let json:Object = try? json ~> "sign_request" {
            self.sign = try SignRequest(json: json)
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
        
        if let m = me {
            json["me_request"] = m.object
        }

        if let u = unpair {
            json["unpair_request"] = u.object
        }

        return json
    }

    func isNoOp() -> Bool {
        return sign == nil && me == nil && unpair == nil
    }
}

//MARK: Requests

// Sign

struct HostAuthVerificationFailed:Error{}

struct SignRequest:Jsonable {
    var data:Data
    var fingerprint:String
    let hostAuth:HostAuth?
    
    struct InvalidSessionData:Error{}
    struct InvalidHostAuthSignature:Error{}

    
    init(json: Object) throws {
        data        = try ((json ~> "data") as String).fromBase64()
        fingerprint = try json ~> "public_key_fingerprint"
        
        do {
            let json:Object = try json ~> "host_auth"
            
            guard data.count >= 36 else {
                throw InvalidSessionData()
            }

            let sessionID = data.subdata(in: 4..<36)
            
            let auth = try HostAuth(json: json)
            
            guard data.count >= 36 else {
                throw InvalidSessionData()
            }

            guard try auth.verify(sessionID: sessionID) == true
            else {
                throw InvalidHostAuthSignature()
            }
            
            hostAuth = auth

        } catch {
            log("host auth error: \(error)")
            hostAuth = nil
        }
    }
    
    var object: Object {
        var json:[String:Any] = ["data": data.toBase64(),
                                 "public_key_fingerprint": fingerprint]
        
        if let auth = hostAuth {
            json["host_auth"] = auth.object
        }
        
        return json
    }
    
    
 
    var user:String? {
        guard data.count >= 38 else {
            return nil
        }
        
        //  user field starts at bytes[37]
        let userLen = Int32(bigEndianBytes: [UInt8](data.subdata(in: 37..<41)))
        if userLen > 0 && data.count > Int(userLen + 41) {
            let userCStringBytes = data.subdata(in: 41..<Int(41+userLen))
            let user = String(bytes: userCStringBytes, encoding: .utf8)
            log("userLen \(userLen) user \(user)")
            return user
        }
        
        return nil
    }

    var display:String {
        let host = hostAuth?.hostNames.first ?? "unknown host"
        
        if let user = user {
            return "\(user) @ \(host)"
        }
        
        return host
    }

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





