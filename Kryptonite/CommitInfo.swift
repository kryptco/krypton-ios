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
    let tree: String
    var parent: String?
    let author: String
    let committer: String
    let message: Data

    // computed properties
    let data:Data
    let shortDisplay:String
    
    init(tree: String, parent: String?, author: String, committer: String, message: Data) throws {
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
        try data.append(tree.utf8Data())
        
        data.append(newLine)
        
        // parent
        if let parent = self.parent {
            try data.append("parent ".utf8Data())
            try data.append(parent.utf8Data())
            data.append(newLine)
        }
        
        // author
        try data.append("author ".utf8Data())
        try data.append(author.utf8Data())
        
        data.append(newLine)
        
        // committer
        try data.append("committer ".utf8Data())
        try data.append(committer.utf8Data())

        // empty line
        data.append(newLine)
        
        // message
        data.append(message)

        self.data = data
        
        
        /**
            Create a human-readable display
         */
        let messageString = try message.utf8String()
        
        if author == committer {
            shortDisplay = "\(messageString.trimmingCharacters(in: CharacterSet.newlines))\n[author: \(author)]"
        } else {
            shortDisplay = "\(messageString.trimmingCharacters(in: CharacterSet.newlines))\n[author: \(author)]\n[committer: \(committer)]"
        }
    }
    
    init(json: Object) throws {
        try self.init(
            tree: try json ~> "tree",
            parent: try? json ~> "parent",
            author: try json ~> "author",
            committer: json ~> "committer",
            message: try ((json ~> "message") as String).fromBase64()
        )
    }

    var object: Object {
        var map : Object = [
            "tree": tree,
            "author": author,
            "committer": committer,
            "message": message.toBase64()
        ]
        
        if let parent = self.parent {
            map["parent"] = parent
        }
        
        return map
    }
}
