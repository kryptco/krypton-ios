//
//  UserIDList.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct UserIDList:Jsonable {
    private static let key = "user_ids"
    
    let ids:[String]
    
    init(ids:[String]) {
        self.ids = ids
    }
    init(json: Object) throws {
        try self.init(ids: json ~> UserIDList.key)
    }
    
    var object: Object {
        return [UserIDList.key: ids]
    }
    
    func by(adding userID:String) -> UserIDList {
        return UserIDList(ids: ids + [userID])
    }
}
