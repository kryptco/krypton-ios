//
//  Request.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Response:JSONConvertable {
    
    var requestID:String
    var snsEndpointARN:String
    var sign:SignResponse?
    var list:ListResponse?
    var me:MeResponse?
    
    init(json: JSON) throws {
        self.requestID = try json ~> "request_id"
        self.snsEndpointARN = try json ~> "sns_endpoint_arn"

        if let json:JSON = try? json ~> "sign_response" {
            self.sign = try SignResponse(json: json)
        }
        
        if let json:JSON = try? json ~> "list_response" {
            self.list = try ListResponse(json: json)
        }
        
        if let json:JSON = try? json ~> "me_response" {
            self.me = try MeResponse(json: json)
        }        
    }
    
    var jsonMap: JSON {
        var json:[String:Any] = [:]
        json["request_id"] = requestID
        json["sns_endpoint_arn"] = snsEndpointARN

        if let s = sign {
            json["sign_response"] = s.jsonMap
        }
        
        if let l = list {
            json["list_response"] = l.jsonMap
        }
        
        if let m = me {
            json["me_response"] = m.jsonMap
        }
        
        return json
    }
}

//MARK: Responses

// Sign

struct SignResponse:JSONConvertable {
    var signature:String
    var error:String
    
    init(json: JSON) throws {
        self.signature = try json ~> "signature"
        self.error = try json ~> "error"
    }
    
    var jsonMap: JSON {
        return ["signature": signature,
                "error": error]
    }
}


// List
struct ListResponse:JSONConvertable {
    var peers:[Peer]
    init(json: JSON) throws {
        self.peers = try ((json ~> "profiles") as [JSON]).map({try Peer(json: $0)})
    }
    var jsonMap: JSON {
        return ["profiles": peers.map({$0.jsonMap})]
    }
}

// Me
struct MeResponse:JSONConvertable {
    var me:Peer
    init(json: JSON) throws {
        self.me = try Peer(json: json ~> "me")
    }
    var jsonMap: JSON {
        return ["me": me.jsonMap]
    }
}
