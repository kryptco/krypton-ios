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

    init(id: String, unixSeconds: Int, sendACK: Bool, version: Version? = nil, sign: SignRequest? = nil, me: MeRequest? = nil, unpair: UnpairRequest? = nil) {
        self.id = id
        self.unixSeconds = unixSeconds
        self.sendACK = sendACK
        self.version = version
        self.sign = sign
        self.me = me
        self.unpair = unpair
    }
    
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
    //  https://tools.ietf.org/html/rfc4252 section 7
    var data:Data
    var fingerprint:String
    var hostAuth:HostAuth?
    var sessionID:Data?
    var user:String?
    
    struct InvalidSessionData:Error{}
    struct InvalidHostAuthSignature:Error{}

    init(data: Data, fingerprint: String, hostAuth: HostAuth? = nil) throws {
        self.data = data
        self.fingerprint = fingerprint
        try setSessionIDAndUser()
        
        if let hostAuth = hostAuth{
            try verifyAndSetHostAuth(hostAuth: hostAuth)
        }
    }

    mutating func setSessionIDAndUser() throws {
        guard data.count >= 4 else {
            throw InvalidSessionData()
        }
        
        let sessionIDLenBigEndianBytes = data.subdata(in: 0 ..< 4)
        guard let sessionIDLen = UInt32(exactly: Int32(bigEndianBytes: [UInt8](sessionIDLenBigEndianBytes))) else {
            throw InvalidSessionData()
        }
        let sessionIDStart = 4
        let sessionIDEnd = sessionIDStart + Int(sessionIDLen)
        guard data.count >= Int(sessionIDEnd) else {
            throw InvalidSessionData()
        }
        self.sessionID = data.subdata(in: sessionIDStart..<Int(sessionIDEnd))

        let userLenStart = sessionIDEnd + 1
        let userLenEnd = userLenStart + 4
        guard data.count >= Int(userLenEnd) else {
            throw InvalidSessionData()
        }
        
        let userLen = UInt32(Int32(bigEndianBytes: [UInt8](data.subdata(in: Int(userLenStart)..<Int(userLenEnd)))))
        let userStart = userLenEnd
        let userEnd = userStart + Int(userLen)
        if userLen > 0 && data.count >= Int(userEnd) {
            let userCStringBytes = data.subdata(in: Int(userStart)..<Int(userEnd))
            let user = String(bytes: userCStringBytes, encoding: .utf8)
            self.user = user
        }
    }

    mutating func verifyAndSetHostAuth(hostAuth: HostAuth) throws {
        guard let sessionID = sessionID else {
            return
        }
        guard try hostAuth.verify(sessionID: sessionID) == true
            else {
                log("hostauth verify failed: \(hostAuth) digest \(data.toBase64())")
                throw InvalidHostAuthSignature()
        }
        self.hostAuth = hostAuth
    }
    
    init(json: Object) throws {
        data        = try ((json ~> "data") as String).fromBase64()
        fingerprint = try json ~> "public_key_fingerprint"

        do {
            try setSessionIDAndUser()
            
            let json:Object = try json ~> "host_auth"

            let auth = try HostAuth(json: json)
            try verifyAndSetHostAuth(hostAuth: auth)
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





