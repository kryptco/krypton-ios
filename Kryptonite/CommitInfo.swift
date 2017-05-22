//
//  CommitInfo.swift
//  Kryptonite
//
//  Created by Kevin King on 5/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import JSON

struct CommitInfo: Jsonable {
    var tree: Data
    var parent: Data
    var author: Data
    var committer: Data
    var message: Data

    init(tree: Data, parent: Data, author: Data, committer: Data, message: Data) {
        self.tree = tree
        self.parent = parent
        self.author = author
        self.committer = committer
        self.message = message
    }
    init(json: Object) throws {
        self.init(
            tree: try ((json ~> "tree") as String).fromBase64(),
            parent: try ((json ~> "parent") as String).fromBase64(),
            author: try ((json ~> "author") as String).fromBase64(),
            committer: try ((json ~> "committer") as String).fromBase64(),
            message: try ((json ~> "message") as String).fromBase64()
        )
    }
    
    var object: Object {
        return [
            "tree": tree.toBase64(),
            "parent": parent.toBase64(),
            "author": author.toBase64(),
            "committer": committer.toBase64(),
            "message": message.toBase64()
        ]
    }
    
    func toData() throws -> Data {
        var data = Data()
        
        // tree
        try data.append("tree ".utf8Data())
        data.append(tree)
        
        try data.append("\n".utf8Data())

        // parent
        try data.append("parent ".utf8Data())
        data.append(parent)
        
        try data.append("\n".utf8Data())
        
        // author
        try data.append("author ".utf8Data())
        data.append(author)
        
        try data.append("\n".utf8Data())
        
        // committer
        try data.append("committer ".utf8Data())
        data.append(committer)
        
        try data.append("\n".utf8Data())
        
        // empty line
        try data.append("\n".utf8Data())
        
        // message
        data.append(message)
        
        return data
    }
}
