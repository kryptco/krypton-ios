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
    private static let upperBound = 10240 // upper bound on
    
    let ids:[String]
    
    init(ids:[String]) throws {
        guard try ids.reduce(0, { try $0 + $1.utf8Data().count }) < UserIDList.upperBound else {
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
    
    func by(adding userID:String) throws -> UserIDList {
        return try UserIDList(ids: ids + [userID])
    }
    
    static var empty:UserIDList {
        return UserIDList()
    }
}
