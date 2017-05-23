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
    let tree: Data
    var parent: Data?
    let author: Data
    let committer: Data
    let message: Data

    // computed properties
    let data:Data
    let shortDisplay:String
    
    init(tree: Data, parent: Data?, author: Data, committer: Data, message: Data) throws {
        self.tree = tree
        self.parent = parent
        self.author = author
        self.committer = committer
        self.message = message
        
        /** 
            Put the commit info in the correct byte sequence
        */
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

        self.data = data
        
        
        /**
            Create a human-readable display
         */
        let authorString = try author.utf8String()
        let committerString = try committer.utf8String()
        let messageString = try message.utf8String()
        
        if authorString == committerString {
            shortDisplay = "\(messageString.trimmingCharacters(in: CharacterSet.newlines))\n[author: \(authorString)]"
        } else {
            shortDisplay = "\(messageString.trimmingCharacters(in: CharacterSet.newlines))\n[author: \(authorString)]\n[committer: \(committerString)]"
        }
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
}
