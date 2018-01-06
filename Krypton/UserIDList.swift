//
//  UserIDList.swift
//  Krypton
//
//  Created by Alex Grinman on 5/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct UserIDList:Jsonable {
    private static let key = "user_ids"
    
    private static let maxCount = 3
    
    let ids:[String]
    
    init(ids:[String]) {
        var idsToSet = [String](ids)
        
        // take only the most recently used (the first `maxCount` # of ids)
        if ids.count > UserIDList.maxCount {
            idsToSet = [String](idsToSet[0 ..< UserIDList.maxCount])
        }
        
        self.ids = idsToSet
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
    func by(updating userID:String) -> UserIDList {
        
        // if the id is already here, repriortize it
        if let idIndex = ids.index(of: userID) {
            var newIDs = ids
            newIDs.remove(at: idIndex)
            newIDs.insert(userID, at: 0)
            
            return UserIDList(ids: newIDs)
        }
                
        return UserIDList(ids: [userID] + ids)
    }
    
    static var empty:UserIDList {
        return UserIDList()
    }
}
