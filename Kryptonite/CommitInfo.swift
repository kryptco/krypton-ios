//
//  CommitInfo.swift
//  Kryptonite
//
//  Created by Kevin King on 5/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import JSON

struct InvalidCommitInfo:Error {}
struct CommitInfo: Jsonable {
    var tree: Data
    var parent: Data?
    var author: Data
    var committer: Data
    var message: Data

    var display:String
    var shortDisplay:String
    
    init(tree: Data, parent: Data?, author: Data, committer: Data, message: Data) throws {
        self.tree = tree
        self.parent = parent
        self.author = author
        self.committer = committer
        self.message = message
        
        // create the string displays
        let treeHash = try tree.utf8String()
        let treeString = "tree \(treeHash)"
        
        var parentString = ""
        if let theParent = parent {
            parentString = try "\nparent \(theParent.utf8String())"
        }
        
        let authorString = try "\nauthor \(author.utf8String())"
        let committerString = try "commiter \(committer.utf8String())"
        let messageString = try message.utf8String()

        guard treeHash.characters.count >= 6
        else {
            throw InvalidCommitInfo()
        }
        
        self.display = "\(treeString)\(parentString)\n\(authorString)\n\(committerString)\n\(messageString)".trimmingCharacters(in: CharacterSet.newlines)
        
        let shortCommit = treeHash.substring(to: treeHash.index(treeHash.startIndex, offsetBy: 6))
        self.shortDisplay = "\(shortCommit): \(messageString.trimmingCharacters(in: CharacterSet.newlines))"
    }
    
    init(json: Object) throws {
        
        var parent:Data?
        if let parentBase64:String = try? json ~> "parent" {
            parent = try parentBase64.fromBase64()
        }
        
        try self.init(
            tree: try ((json ~> "tree") as String).fromBase64(),
            parent: parent,
            author: try ((json ~> "author") as String).fromBase64(),
            committer: try ((json ~> "committer") as String).fromBase64(),
            message: try ((json ~> "message") as String).fromBase64()
        )
    }
    
    var object: Object {
        var map = [
            "tree": tree.toBase64(),
            "author": author.toBase64(),
            "committer": committer.toBase64(),
            "message": message.toBase64()
        ]
        
        if let parent = self.parent {
            map["parent"] = parent.toBase64()
        }
        
        return map
    }
    
    func toData() throws -> Data {
        var data = Data()
        
        let newLine = try "\n".utf8Data()

        // tree
        try data.append("tree ".utf8Data())
        data.append(tree)
        
        data.append(newLine)

        // parent
        if let parent = self.parent {
            try data.append("parent ".utf8Data())
            data.append(parent)
            data.append(newLine)
        }
        
        // author
        try data.append("author ".utf8Data())
        data.append(author)
        
        data.append(newLine)
        
        // committer
        try data.append("committer ".utf8Data())
        data.append(committer)
        
        // empty line
        data.append(newLine)
        
        // message
        data.append(message)

        return data
    }
}
