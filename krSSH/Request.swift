//
//  Request.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Request:JSONConvertable {
    
    var requestID:String
    var sign:SignRequest?
    var list:ListRequest?
    var me:MeRequest?
    
    init(json: JSON) throws {
        self.requestID = try json ~> "request_id"
        
        if let json:JSON = try? json ~> "sign_request" {
            self.sign = try SignRequest(json: json)
        }
        
        if let json:JSON = try? json ~> "list_request" {
            self.list = try ListRequest(json: json)
        }
        
        if let json:JSON = try? json ~> "me_request" {
            self.me = try MeRequest(json: json)
        }
        
        throw JSONParsingError.invalid
    }
    
    var jsonMap: JSON {
        var json:[String:Any] = [:]
        json["request_id"] = requestID
        
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
enum HashName:String {
    case SHA256 = "SHA256"
    case SHA1   = "SHA1"
}

struct SignRequest:JSONConvertable {
    var message:String
    var fingerprint:String
    var hashName:HashName
    
    init(json: JSON) throws {
        self.message = try json ~> "message"
        self.fingerprint = try json ~> "public_key_fingerprint"
        
        let hn:String = try json ~> "hash_name"
        guard let hashName = HashName(rawValue: hn) else {
            throw JSONParsingError.invalidValue(k: "hash_name", v: hn)
        }
        self.hashName = hashName
        
        throw JSONParsingError.invalid
    }
    
    var jsonMap: JSON {
        return ["message": message,
                "public_key_fingerprint": fingerprint,
                "hash_name": hashName.rawValue]
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






