//
//  Request.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Request:JSONConvertable {
    
    var id:String
    var unixSeconds: Int
    var sign:SignRequest?
    var list:ListRequest?
    var me:MeRequest?
    
    init(json: JSON) throws {
        self.id = try json ~> "request_id"
        unixSeconds = try json ~> "unix_seconds"
        
        if let json:JSON = try? json ~> "sign_request" {
            self.sign = try SignRequest(json: json)
        }
        
        if let json:JSON = try? json ~> "list_request" {
            self.list = try ListRequest(json: json)
        }
        
        if let json:JSON = try? json ~> "me_request" {
            self.me = try MeRequest(json: json)
        }
        
    }
    
    var jsonMap: JSON {
        var json:[String:Any] = [:]
        json["request_id"] = id
        json["unix_seconds"] = unixSeconds

        if let s = sign {
            json["sign_request"] = s.jsonMap
        }
        
        if let l = list {
            json["list_request"] = l.jsonMap
        }
        
        if let m = me {
            json["me_request"] = m.jsonMap
        }
        
        return json
    }
}

//MARK: Requests

// Sign

struct SignRequest:JSONConvertable {
    var digest:String
    var fingerprint:String
    
    init(json: JSON) throws {
        self.digest = try json ~> "digest"
        self.fingerprint = try json ~> "public_key_fingerprint"
    }
    
    var jsonMap: JSON {
        return ["message": digest,
                "public_key_fingerprint": fingerprint]
    }
}


// List
struct ListRequest:JSONConvertable {
    init(json: JSON) throws {}
    var jsonMap: JSON {return [:]}
}

// Me
struct MeRequest:JSONConvertable {
    init(json: JSON) throws {}
    var jsonMap: JSON {return [:]}
}






