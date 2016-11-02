//
//  Request.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

final class Response:JSONConvertable {
    
    var requestID:String
    var snsEndpointARN:String
    var version:Version?
    var approvedUntil:Int?
    var sign:SignResponse?
    var list:ListResponse?
    var me:MeResponse?
    var unpair:UnpairResponse?
    var ack:AckResponse?
    var trackingID:String?
    
    init(requestID:String, endpoint:String, approvedUntil:Int? = nil, sign:SignResponse? = nil, list:ListResponse? = nil, me:MeResponse? = nil, unpair:UnpairResponse? = nil, ack:AckResponse? = nil, trackingID:String? = nil) {
        self.requestID = requestID
        self.snsEndpointARN = endpoint
        self.approvedUntil = approvedUntil
        self.sign = sign
        self.list = list
        self.me = me
        self.unpair = unpair
        self.ack = ack
        self.trackingID = trackingID
        self.version = Properties.currentVersion
    }
    
    init(json: JSON) throws {
        self.requestID = try json ~> "request_id"
        self.snsEndpointARN = try json ~> "sns_endpoint_arn"
        self.version = Version(string: try json ~> "v")

        if let approvedUntil:Int = try? json ~> "approved_until" {
            self.approvedUntil = approvedUntil
        }

        if let json:JSON = try? json ~> "sign_response" {
            self.sign = try SignResponse(json: json)
        }
        
        if let json:JSON = try? json ~> "list_response" {
            self.list = try ListResponse(json: json)
        }
        
        if let json:JSON = try? json ~> "me_response" {
            self.me = try MeResponse(json: json)
        }

        if let json:JSON = try? json ~> "unpair_response" {
            self.unpair = UnpairResponse(json: json)
        }

        if let json:JSON = try? json ~> "ack_response" {
            self.ack = AckResponse(json: json)
        }

        if let trackingID:String = try? json ~> "tracking_id" {
            self.trackingID = trackingID
        }
    }
    
    var jsonMap: JSON {
        var json:[String:Any] = [:]
        json["request_id"] = requestID
        json["sns_endpoint_arn"] = snsEndpointARN
        
        if let approvedUntil = approvedUntil {
            json["approved_until"] = approvedUntil
        }

        if let s = sign {
            json["sign_response"] = s.jsonMap
        }
        
        if let l = list {
            json["list_response"] = l.jsonMap
        }
        
        if let m = me {
            json["me_response"] = m.jsonMap
        }

        if let u = unpair {
            json["unpair_response"] = u.jsonMap
        }

        if let a = ack {
            json["ack_response"] = a.jsonMap
        }

        if let trackingID = self.trackingID {
            json["tracking_id"] = trackingID
        }

        if let v = self.version {
            json["v"] = v.string
        }

        return json
    }
}

//MARK: Responses

// Sign

struct SignResponse:JSONConvertable {
    var signature:String?
    var error:String?
    
    init(sig:String?, err:String? = nil) {
        self.signature = sig
        self.error = err
    }
    
    init(json: JSON) throws {
        
        if let sig:String = try? json ~> "signature" {
            self.signature = sig
        }
        
        if let err:String = try? json ~> "error" {
            self.error = err
        }
    }
    
    var jsonMap: JSON {
        var map = [String:Any]()
        
        if let sig = signature {
            map["signature"] = sig
        }
        if let err = error {
            map["error"] = err
        }
        return map
    }
}


// List
struct ListResponse:JSONConvertable {
    var peers:[Peer]
    
    init(peers:[Peer]) {
        self.peers = peers
    }
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
    init(me:Peer) {
        self.me = me
    }
    init(json: JSON) throws {
        self.me = try Peer(json: json ~> "me")

    }
    var jsonMap: JSON {
        return ["me": me.jsonMap]
    }
}

// Unpair
struct UnpairResponse:JSONConvertable {
    init(){}
    init(json: JSON) {

    }
    var jsonMap: JSON {
        return [:]
    }
}

// Ack
struct AckResponse:JSONConvertable {
    init(){}
    init(json: JSON) {

    }
    var jsonMap: JSON {
        return [:]
    }
}
