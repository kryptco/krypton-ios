//
//  UserIDList.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct TooManyUserIDs:Error{}
struct UserIDList:Jsonable {
    private static let key = "user_ids"
    
    private static let maxCount = 3
    
    let ids:[String]
    
    init(ids:[String]) throws {
        guard ids.count <= UserIDList.maxCount else {
            throw TooManyUserIDs()
        }
        self.ids = ids
    }
    
    init(json: Object) throws {
        try self.init(ids: json ~> UserIDList.key)
    }
    
    private init() {
        self.ids = []
    }
    
    var object: Object {
        return [UserIDList.key: ids]
    }
    
    func has(_ userID:String) -> Bool {
        return ids.contains(userID)
    }
    
    /**
        Add a user_id to the list if needed:
            - if the id exists, update it's priority (lower index = more recently used)
            - otherwise, add the id to the front, cutting off id's > maxCount
     */
    func by(updating userID:String) throws -> UserIDList {
        
        // if the id is already here, repriortize it
        if let idIndex = ids.index(of: userID) {
            var newIDs = ids
            newIDs.remove(at: idIndex)
            newIDs.insert(userID, at: 0)
            
            return try UserIDList(ids: newIDs)
        }
        
        var newIDs = [userID] + ids
        
        if newIDs.count > UserIDList.maxCount {
            newIDs = [String](newIDs[0 ..< UserIDList.maxCount])
        }
        
        return try UserIDList(ids: newIDs)
    }
    
    static var empty:UserIDList {
        return UserIDList()
    }
}
