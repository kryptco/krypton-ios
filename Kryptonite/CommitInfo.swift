//
//  CommitInfo.swift
//  Kryptonite
//
//  Created by Kevin King on 5/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import JSON

struct InvalidCommitInfo:Error {}
struct InvalidCommitHash:Error {}

struct CommitInfo: Jsonable {
    let tree: String
    var parent: String?
    let author: String
    let committer: String
    let message: Data

    // computed properties
    let messageString:String
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
        messageString = (try? message.utf8String().trimmingCharacters(in: CharacterSet.newlines)) ?? "message decoding error"
        
        if author == committer {
            shortDisplay = "\(messageString) [\(author)]"
        } else {
            shortDisplay = "\(messageString) [\(author)]\n[committer: \(committer)]"
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
    
    func commitHash(asciiArmoredSignature:String) throws -> Data {
        
        let newLine = try "\n".utf8Data()

        var commitData = Data()
    
        // tree
        try commitData.append("tree ".utf8Data())
        try commitData.append(tree.utf8Data())
        
        commitData.append(newLine)
        
        // parent
        if let parent = self.parent {
            try commitData.append("parent ".utf8Data())
            try commitData.append(parent.utf8Data())
            commitData.append(newLine)
        }
        
        // author
        try commitData.append("author ".utf8Data())
        try commitData.append(author.utf8Data())
        
        commitData.append(newLine)
        
        // committer
        try commitData.append("committer ".utf8Data())
        try commitData.append(committer.utf8Data())
        commitData.append(newLine)

        // append gpgsig
        try commitData.append("gpgsig".utf8Data())        
        let spaceAdjustedAsciiArmor = asciiArmoredSignature.components(separatedBy: .newlines).map({ " " + $0}).joined(separator: "\n")
        try commitData.append(spaceAdjustedAsciiArmor.utf8Data())
        commitData.append(newLine)
        
        // message
        commitData.append(message)
        
        // prepend precommit data: "commit LEN\0"
        let commitDataLength = commitData.count
        var preCommitData = try Data("commit \(commitDataLength)".utf8Data())
        preCommitData.append(contentsOf: [0x00])
        
        // append remainder of commitData
        preCommitData.append(commitData)
        

        // compute sha1 and return
        return preCommitData.SHA1
    }
    
    func shortCommitHash(asciiArmoredSignature:String) throws -> String {
        let commitHash = try self.commitHash(asciiArmoredSignature: asciiArmoredSignature).hex
        
        guard commitHash.characters.count >= 7 else {
            throw InvalidCommitHash()
        }
        let commitHashShort = commitHash.substring(to: commitHash.index(commitHash.startIndex, offsetBy: 7))
        
        
        return commitHashShort
    }
}




