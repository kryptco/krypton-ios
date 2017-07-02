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
    var version:Version
    var body:RequestBody
    

    init(id: String, unixSeconds: Int, sendACK: Bool, version: Version, body:RequestBody) {
        self.id = id
        self.unixSeconds = unixSeconds
        self.sendACK = sendACK
        self.version = version
        self.body = body
    }
    
    init(json: Object) throws {
        self.id = try json ~> "request_id"
        self.unixSeconds = try json ~> "unix_seconds"
        self.sendACK = (try? json ~> "a") ?? false
        self.version = try Version(string: json ~> "v")
        self.body = try RequestBody(json: json)
    }
    
    var object:Object {
        var json = body.object
        
        json["request_id"] = id
        json["unix_seconds"] = unixSeconds
        json["a"] = sendACK
        json["v"] = version.string

        return json
    }
}

struct MultipleRequestsError:Error {}

enum RequestBody:Jsonable {
    case me(MeRequest)
    case ssh(SignRequest)
    case git(GitSignRequest)
    case blob(BlobSignRequest)
    case unpair(UnpairRequest)
    case noOp
    
    
    var isApprovable:Bool {
        switch self {
        case .ssh, .git, .blob:
            return true
        case .me, .unpair, .noOp:
            return false
        }
    }

    
    init(json:Object) throws {
        
        var requests:[RequestBody] = []
        
        // parse the requests
        if let json:Object = try? json ~> "me_request" {
            requests.append(.me(try MeRequest(json: json)))
        }

        if let json:Object = try? json ~> "sign_request" {
            requests.append(.ssh(try SignRequest(json: json)))
        }
        
        if let json:Object = try? json ~> "git_sign_request" {
            requests.append(.git(try GitSignRequest(json: json)))
        }
        
        if let json:Object = try? json ~> "blob_sign_request" {
            requests.append(.blob(try BlobSignRequest(json: json)))
        }
        
        if let json:Object = try? json ~> "unpair_request" {
            requests.append(.unpair(try UnpairRequest(json: json)))
        }
        
        
        // if no requests, it's a noOp
        if requests.isEmpty {
            self = .noOp
            return
        }
        
        // if more than one request, it's an error
        if requests.count > 1 {
            throw MultipleRequestsError()
        }
        
        // set the request type
        self = requests[0]
    }
    
    var object:Object {
        var json = Object()
        
        switch self {
        case .me(let m):
            json["me_request"] = m.object
        case .ssh(let s):
            json["sign_request"] = s.object
        case .git(let g):
            json["git_sign_request"] = g.object
        case .blob(let b):
            json["blob_sign_request"] = b.object
        case .unpair(let u):
            json["unpair_request"] = u.object
        case .noOp:
            break
        }
        
        return json
    }
    
    var analyticsCategory:String {
        switch self {
        case .ssh:
            return "signature"
        case .git(let g):
            switch g.git {
            case .commit:
                return "git-commit-signature"
            case .tag:
                return "git-tag-signature"
            }
        case .me:
            return "me"
        case .noOp:
            return "noOp"
        case .unpair:
            return "unpair"
        }
    }
}


//MARK: Requests

struct HostAuthVerificationFailed:Error{}

struct SignRequest:Jsonable {
    var data:SSHMessage //SSH_MSG_USERAUTH_REQUEST
    var fingerprint:String
    var verifiedHostAuth:VerifiedHostAuth?
    
    var session:Data
    var user:String
    var digestType:DigestType
    
    
    var isUnknownHost:Bool {
        return verifiedHostAuth?.hostName == nil
    }

    init(data: Data, fingerprint: String, hostAuth: HostAuth? = nil) throws {
        self.data = SSHMessage(data)
        self.fingerprint = fingerprint

        (session, user, digestType) = try SignRequest.parse(requestData: data)

        // TODO: Phase out "unknown host" asap
        // currently requests made while agent forwarding (ssh -A) aren't able to pass 
        // host_auth data to kr.
        if let potentialHostAuth = hostAuth {
            self.verifiedHostAuth = try? VerifiedHostAuth(session: session, hostAuth: potentialHostAuth)
        }
    }

    init(json: Object) throws {
        try self.init(data: ((json ~> "data") as String).fromBase64(),
                      fingerprint: json ~> "public_key_fingerprint",
                      hostAuth: try? HostAuth(json: json ~> "host_auth"))
    }
    
    /**
     Parse request data to get session, user, and digest algorithm type
     - throws: InvalidRequestData if data doesn't parse correctly.
     
     Parses according to the SSH packet protocol: https://tools.ietf.org/html/rfc4252#section-7
     
     Packet Format (SSH_MSG_USERAUTH_REQUEST):
         string    session identifier
         byte      SSH_MSG_USERAUTH_REQUEST
         string    user name
         string    service name
         string    "publickey"
         boolean   TRUE
         string    public key algorithm name
         
         /// Note: krd removes this to save space
         string    public key to be used for authentication
     */
    static func parse(requestData:SSHMessage) throws -> (session:Data, user:String, digestType:DigestType) {
        var data = Data(requestData)
        // session
        let session = try data.popData()
        
        // type
        let _ = try data.popByte()
        
        // user
        let user = try data.popString()
        
        // service, method, sign
        let _ = try data.popString()
        let _ = try data.popString()
        let _ = try data.popBool()

        let algo = try data.popString()
        
        let digestType = try DigestType(algorithmName: algo)
        
        return (session, user, digestType)
    }
    
    var object: Object {
        var json:[String:Any] = ["data": data.toBase64(),
                                 "public_key_fingerprint": fingerprint]
        
        if let auth = verifiedHostAuth {
            json["host_auth"] = auth.object
        }
        
        return json
    }
    
    var display:String {
        let host = verifiedHostAuth?.hostName ?? "unknown host"

        return "\(user) @ \(host)"
    }
}

struct GitSignRequest:Jsonable {
    let userId:String
    let git: GitInfo
    
    init(userId: String, git: GitInfo) {
        self.userId = userId
        self.git = git
    }

    init(json: Object) throws {
        self.init(
            userId: try json ~> "user_id",
            git: try GitInfo(json: json)
        )
    }
    
    var object: Object {
        var json = git.object
        
        json["user_id"] = userId
        
        return json
    }
}

struct BlobSignRequest:Jsonable {
    let blob:String
    let sigType:SigType
    
    struct InvalidSigType:Error {}
    enum SigType:String {
        case detach    = "detach"
        case attach    = "attach"
        case clearsign = "clearsign"
        
        init(type:String) throws {
            guard let sigType = SigType(rawValue: type) else {
                throw InvalidSigType()
            }
            
            self = sigType
        }
    }
    
    init(blob:String, sigType:SigType) {
        self.blob = blob
        self.sigType = sigType
    }
    
    init(json: Object) throws {
        self.init(
            blob:       try json ~> "blob",
            sigType:    try SigType(type: json ~> "sig_type")
        )
    }
    
    var object: Object {
        var json = Object()
        
        json["blob"] = blob
        json["sig_type"] = sigType.rawValue

        return json
    }
}


// Me
struct MeRequest:Jsonable {
    var pgpUserId: String?
    init(pgpUserId: String? = nil) {
        self.pgpUserId = pgpUserId
    }
    init(json: Object) throws {
        pgpUserId = try? json ~> "pgp_user_id"
    }
    var object: Object {
        var json:Object = [:]
        if let pgpUserId = pgpUserId {
            json["pgp_user_id"] = pgpUserId
        }
        return json
    }
}

// Unpair
struct UnpairRequest:Jsonable {
    init(json: Object) throws {}
    var object: Object {return [:]}
}




