//
//  TeamAuditLog.swift
//  Krypton
//
//  Created by Alex Grinman on 10/23/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

class Audit {
    
    struct Session:JsonWritable {
        let deviceName:String
        let workstationPublicKeyDoubleHash:Data
        
        var object:Object {
            return ["device_name": deviceName,
                    "workstation_public_key_double_hash": workstationPublicKeyDoubleHash.toBase64()]
        }
    }
    
    struct Log:JsonWritable {
        let session:Session
        let unixSeconds:UInt64
        let body:LogBody
        
        init(session:Session, body: LogBody) {
            self.session = session
            self.unixSeconds = UInt64(Date().timeIntervalSince1970)
            self.body = body
        }
        
        var object: Object {
            return ["session": session.object,
                    "unix_seconds": unixSeconds,
                    "body": body.object]
        }
    }
    
    enum LogBody:JsonWritable {
        case ssh(SSHSignature)
        case gitCommit(GitCommitSignature)
        case gitTag(GitTagSignature)
        
        var object: Object {
            switch self {
            case .ssh(let sshSig):
                return ["ssh": sshSig.object]
            case .gitCommit(let commitSig):
                return ["git_commit": commitSig.object]
            case .gitTag(let tagSig):
                return ["git_tag": tagSig.object]
            }
        }
    }
    
    // ssh
    struct SSHSignature:JsonWritable {
        let user:String
        let hostAuthorization:HostAuthorization?
        let sessionData:Data
        let result:Result
        
        enum Result:JsonWritable {
            case userRejected
            case hostMismatch([Data]) // expected public key(s)
            case signature(Data)
            case error(String)
            
            var object: Object {
                switch self {
                case .userRejected:
                    return ["user_rejected": [:]]
                case .hostMismatch(let publicKeys):
                    return ["host_mismatch": publicKeys.map({ $0.toBase64() })]
                case .signature(let signature):
                    return ["signature": signature.toBase64()]
                case .error(let error):
                    return ["error": error]
                }
            }
        }
        
        init(user:String, verifiedHostAuth:VerifiedHostAuth?, sessionData:Data, result:Result) {
            self.user = user
            
            if let hostAuth = verifiedHostAuth {
                self.hostAuthorization = HostAuthorization(verifiedHostAuth: hostAuth)
            } else {
                self.hostAuthorization = nil
            }
            
            self.sessionData = sessionData
            self.result = result
        }
        
        var object: Object {
            var obj:Object = ["user": user,
                              "session_data": sessionData.toBase64(),
                              "result": result.object]
            
            if let hostAuth = hostAuthorization {
                obj["host_authorization"] = hostAuth.object
            }
  
            return obj
        }
    }

    struct HostAuthorization:JsonWritable {
        let host:String
        let publicKey:Data
        let signature:Data
        
        init(verifiedHostAuth: VerifiedHostAuth) {
            self.host = verifiedHostAuth.hostname
            self.publicKey = verifiedHostAuth.hostKey
            self.signature = verifiedHostAuth.signature
        }
        
        var object: Object {
            return ["host": host,
                    "public_key": publicKey.toBase64(),
                    "signature": signature.toBase64()]
        }

        func toHostAuth() -> HostAuth {
            return HostAuth(hostKey: publicKey, signature: signature, hostNames: [host])
        }
    }
    
    // git

    
    struct GitCommitSignature:JsonWritable {
        let tree:String
        let parents:[String]
        let author:String
        let committer:String
        let message: Data
        let messageString:String?
        let result:GitSignatureResult
        
        
        init(commitInfo: CommitInfo, result:GitSignatureResult) {
            tree = commitInfo.tree
            
            if let parent = commitInfo.parent {
                parents = [parent] + commitInfo.mergeParents
            } else {
                parents = commitInfo.mergeParents
            }
            
            author = commitInfo.author
            committer = commitInfo.committer
            message = commitInfo.message
            messageString = commitInfo.messageString
            
            self.result = result
        }
        
        var object: Object {
            var obj:Object =  ["tree": tree,
                               "parents": parents,
                               "author": author,
                               "committer": committer,
                               "message": message.toBase64(),
                               "result": result.object]
            if let messageString = messageString {
                obj["message_string"] = messageString
            }
            
            return obj
        }
    }
    struct GitTagSignature:JsonWritable {
        let _object:String
        let tag:String
        let type:String
        let tagger:String
        let message: Data
        let messageString:String?
        let result:GitSignatureResult
        
        init(tagInfo: TagInfo, result:GitSignatureResult) {
            _object = tagInfo._object
            tag = tagInfo.tag
            type = tagInfo.type
            tagger = tagInfo.tagger
            message = tagInfo.message
            messageString = tagInfo.messageString
            
            self.result = result
        }
        
        var object: Object {
            var obj:Object =  ["object": _object,
                               "tag": tag,
                               "type": type,
                               "tagger": tagger,
                               "message": message.toBase64(),
                               "result": result.object]
            
            if let messageString = messageString {
                obj["message_string"] = messageString
            }

            return obj
        }
    }
    
    enum GitSignatureResult:JsonWritable {
        case userRejected
        case signature(Data)
        case error(String)
        
        var object: Object {
            switch self {
            case .userRejected:
                return ["user_rejected": [:]]
            case .signature(let signature):
                return ["signature": signature.toBase64()]
            case .error(let error):
                return ["error": error]
            }
        }
    }
    
}
