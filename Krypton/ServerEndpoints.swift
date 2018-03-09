//
//  ServerEndpoints.swift
//  Krypton
//
//  Created by Alex Grinman on 2/27/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct ServerEndpoints {
    let apiHost:String
    let billingHost:String
}

extension ServerEndpoints:Jsonable {
    init(json: Object) throws {
        try self.init(apiHost: json ~> "api_host",
                      billingHost: json ~> "billing_host")
    }
    
    var object: Object {
        return ["api_host": apiHost, "billing_host": billingHost]
    }
}
