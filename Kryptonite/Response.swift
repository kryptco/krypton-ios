//
//  Request.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

final class Response:Jsonable {
    
    var requestID:String
    var snsEndpointARN:String
    var version:Version?
    var approvedUntil:Int?
    var trackingID:String?
    
    var body:ResponseBody

    init(requestID:String, endpoint:String, body:ResponseBody, approvedUntil:Int? = nil, trackingID:String? = nil) {
        self.requestID = requestID
        self.snsEndpointARN = endpoint
        self.approvedUntil = approvedUntil
        self.body = body
        self.trackingID = trackingID
        self.version = Properties.currentVersion
    }
    
    init(json: Object) throws {
        self.requestID = try json ~> "request_id"
        self.snsEndpointARN = try json ~> "sns_endpoint_arn"
        self.version = try Version(string: json ~> "v")
        self.body = try ResponseBody(json: json)
        
        if let approvedUntil:Int = try? json ~> "approved_until" {
            self.approvedUntil = approvedUntil
        }

        if let trackingID:String = try? json ~> "tracking_id" {
            self.trackingID = trackingID
        }
    }
    
    var object:Object {
        var json = body.object
        json["request_id"] = requestID
        json["sns_endpoint_arn"] = snsEndpointARN
        
        if let approvedUntil = approvedUntil {
            json["approved_until"] = approvedUntil
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

struct MultipleResponsesError:Error {}

enum ResponseBody {
    case me(ResponseResult<MeResponse>)
    case ssh(ResponseResult<SSHSignResponse>)
    case git(ResponseResult<GitSignResponse>)
    case createTeam(ResponseResult<KeyAndTeamCheckpoint>)
    case adminKey(ResponseResult<KeyAndTeamCheckpoint>)
    case ack(ResponseResult<AckResponse>)
    case unpair(ResponseResult<UnpairResponse>)
    
    init(json:Object) throws {
        
        var responses:[ResponseBody] = []
        
        // parse the requests
        if let json:Object = try? json ~> "me_response" {
            responses.append(.me(try ResponseResult<MeResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "sign_response" {
            responses.append(.ssh(try ResponseResult<SSHSignResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "git_sign_response" {
            responses.append(.git(try ResponseResult<GitSignResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "unpair_response" {
            responses.append(.unpair(try ResponseResult<UnpairResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "ack_response" {
            responses.append(.ack(try ResponseResult<AckResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "create_team_response" {
            responses.append(.createTeam(try ResponseResult<KeyAndTeamCheckpoint>(json: json)))
        }

        if let json:Object = try? json ~> "admin_key_response" {
            responses.append(.adminKey(try ResponseResult<KeyAndTeamCheckpoint>(json: json)))
        }

        // if more than one request, it's an error
        if responses.count > 1 {
            throw MultipleResponsesError()
        }
        
        // set the request type
        self = responses[0]
    }
    
    var object:Object {
        var json = Object()
        
        switch self {
        case .me(let m):
            json["me_response"] = m.object
        case .ssh(let s):
            json["sign_response"] = s.object
        case .git(let g):
            json["git_sign_response"] = g.object
        case .createTeam(let c):
            json["create_team_response"] = c.object
        case .adminKey(let a):
            json["admin_key_response"] = a.object
        case .ack(let a):
            json["ack_response"] = a.object
        case .unpair(let u):
            json["unpair_response"] = u.object
        }
        
        return json
    }
    
    var error:String? {
        switch self {
        case .ssh(let sign):
            return sign.error
            
        case .git(let gitSign):
            return gitSign.error
            
        case .createTeam(let createTeam):
            return createTeam.error
        
        case .adminKey(let adminKey):
            return adminKey.error
            
        case .me, .unpair, .ack:
            return nil
        }
    }
}

//MARK: Response Results
enum ResponseResult<T:Jsonable>:Jsonable {
    case ok(T)
    case error(String)
    
    init(json: Object) throws {
        if let err:String = try? json ~> "error" {
            self = .error(err)
            return
        }
        
        self = try .ok(T(json: json))
    }
    
    var object: Object {
        switch self {
        case .ok(let r):
            return r.object
        case .error(let err):
            return ["error": err]
        }
    }
    
    var error:String? {
        switch self {
        case .ok:
            return nil
        case .error(let e):
            return e
        }
    }
}


struct SignatureResponse:Jsonable {
    let signature:String

    init(signature:String) {
        self.signature = signature
    }
    
    init(json: Object) throws {
        try self.init(signature: json ~> "signature")
    }
    
    var object: Object {
        return ["signature": signature]
    }
}

struct EmptyResponse:Jsonable {
    init(){}
    init(json: Object) throws { }
    var object: Object {
        return [:]
    }
}

typealias SSHSignResponse = SignatureResponse
typealias GitSignResponse = SignatureResponse

// Me
struct MeResponse:Jsonable {
    
    struct Me:Jsonable {
        var email:String
        var publicKeyWire:Data
        var pgpPublicKey:Data?
        
        init(email:String, publicKeyWire:Data, pgpPublicKey: Data? = nil) {
            self.email = email
            self.publicKeyWire = publicKeyWire
            self.pgpPublicKey = pgpPublicKey
        }
        
        init(json: Object) throws {
            self.email = try json ~> "email"
            self.publicKeyWire = try ((json ~> "public_key_wire") as String).fromBase64()
            self.pgpPublicKey = try ((json ~> "pgp_pk") as String).fromBase64()
        }
        
        var object: Object {
            var json = ["email": email, "public_key_wire": publicKeyWire.toBase64()]
            if let pgpPublicKey = pgpPublicKey {
                json["pgp_pk"] = pgpPublicKey.toBase64()
            }
            return json
        }
    }
    
    var me:Me
    var team:Team?
    
    init(me:Me, team:Team? = nil) {
        self.me = me
        self.team = team
    }
    init(json: Object) throws {
        self.me = try Me(json: json ~> "me")
        
        if let object:Object = try? json ~> "team" {
            self.team = try Team(json: object)
        }

    }
    var object: Object {
        var map = ["me": me.object]
        
        if let team = self.team {
            map["team"] = team.object
        }
        
        return map
    }
}

typealias UnpairResponse = EmptyResponse
typealias AckResponse = EmptyResponse


// Team
struct KeyAndTeamCheckpoint:Jsonable {
    let seed:Data
    let teamPublicKey:SodiumSignPublicKey
    let lastBlockHash:Data
    
    init(seed:Data, teamPublicKey:SodiumSignPublicKey, lastBlockHash:Data) {
        self.seed = seed
        self.teamPublicKey = teamPublicKey
        self.lastBlockHash = lastBlockHash
    }
    
    init(json: Object) throws {
        try self.init(seed: ((json ~> "seed") as String).fromBase64(),
                      teamPublicKey: ((json ~> "team_public_key") as String).fromBase64(),
                      lastBlockHash: ((json ~> "last_block_hash") as String).fromBase64())
    }
    
    var object: Object {
        return ["key_and_team_checkpoint": [
                    "seed": seed.toBase64(),
                    "team_public_key": teamPublicKey.toBase64(),
                    "last_block_hash": lastBlockHash.toBase64()]
               ]
    }
}

