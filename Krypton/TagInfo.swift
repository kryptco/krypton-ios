//
//  TagInfo.swift
//  Krypton
//
//  Created by Kevin King on 5/22/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import JSON

struct InvalidTagInfo:Error{}

struct TagInfo: Jsonable {
    let _object: GitHash
    let type: String
    let tag: String
    let tagger: String
    let message: Data
    

    // computed properties
    let objectShortHash:String
    let messageString:String
    let data:Data
    let shortDisplay:String
    
    init(object: String, type: String, tag: String, tagger: String, message: Data) throws {
        self._object = object
        self.type = type
        self.tag = tag
        self.tagger = tagger
        self.message = message
        
        /** 
            Put the tag info in the correct byte sequence
        */
        var data = Data()
        
        let newLine = try "\n".utf8Data()
        
        // object
        try data.append("object ".utf8Data())
        try data.append(object.utf8Data())
        
        data.append(newLine)

        // type
        try data.append("type ".utf8Data())
        try data.append(type.utf8Data())
        
        data.append(newLine)
        
        // tag
        try data.append("tag ".utf8Data())
        try data.append(tag.utf8Data())
        
        data.append(newLine)
        
        // tagger
        try data.append("tagger ".utf8Data())
        try data.append(tagger.utf8Data())

        // empty line
        data.append(newLine)
        
        // message
        data.append(message)

        self.data = data
        
        
        /**
            Create a human-readable display
         */
        guard object.count >= 7 else {
            throw InvalidTagInfo()
        }
        objectShortHash = String(object.prefix(7))
        messageString = (try? message.utf8String().trimmingCharacters(in: CharacterSet.newlines)) ?? "message decoding error"
        
        shortDisplay = "[\(self.tag) \(objectShortHash)] \(messageString)"
    }
    
    init(json: Object) throws {
        try self.init(
            object: try json ~> "object",
            type: try json ~> "type",
            tag: try json ~> "tag",
            tagger: json ~> "tagger",
            message: try ((json ~> "message") as String).fromBase64()
        )
    }

    var object: Object {
        return [
            "object": _object,
            "type": type,
            "tag": tag,
            "tagger": tagger,
            "message": message.toBase64()
        ]
    }
}
