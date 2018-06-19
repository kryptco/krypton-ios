//
//  SignatureLog.swift
//  Krypton
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

/** Log Statement for various types of signature logs **/
protocol LogStatement:JsonWritable {
    static var entityName:String { get }
    
    var session:String { get }
    var signature:String { get }
    var date:Date { get }
    var displayName:String { get }
    
    init(object:NSManagedObject) throws
    var managedObject:[String:Any] { get }
    
    var object:Object { get }
}

struct LogStatementParsingError:Error {}

/** SSH */
struct SSHSignatureLog:LogStatement {
    var session:String
    var signature:String
    var date:Date
    var displayName:String
    var hostAuth:String
    
    static var entityName:String {
        return "SignatureLog"
    }
    
    init(object:NSManagedObject) throws {
        guard   let session = object.value(forKey: "session") as? String,
                let signature = object.value(forKey: "signature") as? String,
                let date = object.value(forKey: "date") as? Date,
                let hostAuth = object.value(forKey: "host_auth") as? String,
                let displayName = object.value(forKey: "displayName") as? String
        else {
            throw LogStatementParsingError()
        }
        
        self.init(session: session, hostAuth: hostAuth, signature: signature, displayName: displayName, date: date)
    }
    
    init(session:String, hostAuth:HostAuth?, signature:String, displayName:String, date:Date = Date()) {
        var theHostAuth:String
        if let host = hostAuth, let hostJson = try? host.jsonString() {
            theHostAuth = hostJson
        } else {
            theHostAuth = "unknown"
        }
        
        self.init(session: session, hostAuth: theHostAuth, signature: signature, displayName: displayName, date: date)
    }
    
    init(session:String, hostAuth:String, signature:String, displayName:String, date:Date = Date()) {
        self.session = session  
        self.hostAuth = hostAuth
        self.signature = signature
        self.displayName = displayName
        self.date = date
    }
    
    func getUserAndHost() -> (user:String, host:String)? {
        guard   let hostAuth:HostAuth = try? HostAuth(jsonString: self.hostAuth),
                let hostname = hostAuth.hostNames.first
        else {
            return nil
        }
        
        guard displayName.hasPrefix("rejected: ") == false else {
            return nil
        }
        
        guard let user = displayName.components(separatedBy: "@").first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        else {
            return nil
        }
        
        return (user: user, host: hostname)
    }
    
    var managedObject:[String:Any] {
        return ["session": session,
                "signature": signature,
                "date": date,
                "host_auth": hostAuth,
                "displayName": displayName]
    }
    
    var object: Object {
        return ["session": session,
                "signature": signature,
                "date": date.timeIntervalSince1970,
                "host_auth": hostAuth,
                "displayName": displayName]
    }
}


/** Git Commit */
struct CommitSignatureLog:LogStatement {
    let session:String
    let date:Date
    let signature:String

    let commit:CommitInfo
    let commitHash:GitHash
    
    var displayName:String {
        guard !isRejected else {
            return "Rejected: \(commit.shortDisplay)"
        }
        
        guard commitHash.count >= 7 else {
            return commit.shortDisplay
        }
        
        let commitHashShort = String(commitHash.prefix(7))
        return "[\(commitHashShort)] \(commit.messageString)"
    }
    
    static var entityName:String {
        return "CommitSignatureLog"
    }
    
    init(object:NSManagedObject) throws {
        guard   let session = object.value(forKey: "session") as? String,
                let date = object.value(forKey: "date") as? Date,
                let signature = object.value(forKey: "signature") as? String,
                let commitHash = object.value(forKey: "commit_hash") as? String,
                let tree = object.value(forKey: "tree") as? String,
                let author = object.value(forKey: "author") as? String,
                let committer = object.value(forKey: "committer") as? String,
                let message = object.value(forKey: "message") as? String

        else {
                throw LogStatementParsingError()
        }
        
        let parent = object.value(forKey: "parent") as? String
        let mergeParents = object.value(forKey: "merge_parents") as? [String]
        
        try self.init(session: session, signature: signature, commitHash: commitHash, date: date, commit: CommitInfo(tree: tree, parent: parent, mergeParents: mergeParents, author: author, committer: committer, message: message.fromBase64()))
    }

    init(session:String, signature:String, commitHash:String, date:Date = Date(), commit:CommitInfo) {
        self.session = session
        self.signature = signature
        self.commitHash = commitHash
        self.date = date
        self.commit = commit
    }
    
    var managedObject:[String:Any] {
        var object:[String:Any] =  commit.object
        object["session"] = session
        object["date"] = date
        object["signature"] = signature
        object["commit_hash"] = commitHash
        return object
    }
    
    var object: Object {
        var object:[String:Any] =  commit.object
        object["session"] = session
        object["date"] = date.timeIntervalSince1970
        object["signature"] = signature
        object["commit_hash"] = commitHash
        return object
    }

}

/** Git Tag */
struct TagSignatureLog:LogStatement {
    let session:String
    let signature:String
    let date:Date

    let tag:TagInfo
    
    var displayName:String {
        guard !isRejected else {
            return "Rejected: \(tag.shortDisplay)"
        }

        return tag.shortDisplay
    }

    static var entityName:String {
        return "TagSignatureLog"
    }
    
    init(object:NSManagedObject) throws {
        guard   let session = object.value(forKey: "session") as? String,
            let date = object.value(forKey: "date") as? Date,
            let signature = object.value(forKey: "signature") as? String,
            let obj = object.value(forKey: "object") as? String,
            let type = object.value(forKey: "type") as? String,
            let tag = object.value(forKey: "tag") as? String,
            let tagger = object.value(forKey: "tagger") as? String,
            let message = object.value(forKey: "message") as? String
            
            else {
                throw LogStatementParsingError()
        }
        
        try self.init(session: session, signature: signature, date: date, tag: TagInfo(object: obj, type: type, tag: tag, tagger: tagger, message: message.fromBase64()))
    }
    
    
    
    init(session:String, signature:String, date:Date = Date(), tag:TagInfo) {
        self.session = session
        self.signature = signature
        self.date = date
        self.tag = tag
    }
    
    var managedObject:[String:Any] {
        var object:[String:Any] =  tag.object
        object["session"] = session
        object["date"] = date
        object["signature"] = signature
        return object
    }
    
    var object: Object {
        var object:[String:Any] =  tag.object
        object["session"] = session
        object["date"] = date.timeIntervalSince1970
        object["signature"] = signature
        return object
    }
}

struct U2FLog:LogStatement {
    var session:String
    var signature:String
    var date:Date
    var displayName:String
    var appID:U2FAppID
    var isRegister:Bool
    
    static var entityName:String {
        return "U2FLog"
    }
    
    init(object:NSManagedObject) throws {
        guard   let session = object.value(forKey: "session") as? String,
            let signature = object.value(forKey: "signature") as? String,
            let date = object.value(forKey: "date") as? Date,
            let displayName = object.value(forKey: "displayName") as? String,
            let isRegister = object.value(forKey: "register") as? Bool,
            let appID = object.value(forKey: "app") as? String
        else {
                throw LogStatementParsingError()
        }
        
        
        self.init(session: session, appID: appID, isRegister: isRegister, signature: signature, displayName: displayName, date: date)
    }
    
    init(session:String, appID: U2FAppID, isRegister:Bool, signature:String, displayName:String, date:Date = Date()) {
        self.session = session
        self.appID = appID
        self.isRegister = isRegister
        self.signature = signature
        self.displayName = displayName
        self.date = date
    }
    
    var managedObject:[String:Any] {
        var obj = self.object
        obj["date"] = date
        
        return obj
    }
    
    var object: Object {
        return ["session": session,
                "signature": signature,
                "date": date.timeIntervalSince1970,
                "app": appID,
                "register": isRegister,
                "displayName": displayName]
    }

}

/** 
    Git Signature Logs, identify rejections 
 */
protocol GitSignatureLog:LogStatement {}

extension CommitSignatureLog:GitSignatureLog {}
extension TagSignatureLog:GitSignatureLog {}

extension GitSignatureLog {
    
    static var rejectedConstant:String {
        return "rejected"
    }
    
    var isRejected:Bool {
        return signature == Self.rejectedConstant
    }
}
