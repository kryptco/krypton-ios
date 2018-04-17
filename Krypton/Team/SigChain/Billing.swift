//
//  Billing.swift
//  Krypton
//
//  Created by Alex Grinman on 2/20/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

class SigChainBilling {
    struct Usage {
        let members:UInt64
        let hosts:UInt64
        let logsLastThirtyDays:UInt64
    }
    
    struct Limit {
        let members:UInt64?
        let hosts:UInt64?
        let logsLastThirtyDays:UInt64?
    }
    
    typealias Cents = UInt64

    struct PaymentTier {
        let name:String
        let price:Cents
        let limit:Limit?
        let unitDescription:String
    }
    
    struct BillingInfo {
        let currentTier: PaymentTier
        let usage: Usage
    }
}

// MARK: JSON Ser/Der
extension SigChainBilling.Usage:Jsonable {
    init(json: Object) throws {
        try self.init(members: json ~> "members",
                      hosts: json ~> "hosts",
                      logsLastThirtyDays: json ~> "logs_last_30_days")
    }
    
    var object: Object {
        return ["members": members,
                "hosts": hosts,
                "logs_last_30_days": logsLastThirtyDays]
    }
}


extension SigChainBilling.Limit:Jsonable {
    init(json: Object) throws {
        let members:UInt64? = try? json ~> "members"
        let hosts:UInt64? = try? json ~> "hosts"
        let logsLastThirtyDays:UInt64? = try? json ~> "logs_last_30_days"

        self.init(members: members, hosts: hosts, logsLastThirtyDays: logsLastThirtyDays)
    }
    
    var object: Object {
        var object = Object()
        
        if let members = self.members {
            object["members"] = members
        }
        
        if let hosts = self.hosts {
            object["hosts"] = hosts
        }

        if let logsLastThirtyDays = self.logsLastThirtyDays {
            object["logs_last_30_days"] = logsLastThirtyDays
        }

        return object
    }
}


extension SigChainBilling.PaymentTier:Jsonable {
    init(json: Object) throws {
        try self.init(name: json ~> "name",
                      price: json ~> "price",
                      limit: try? SigChainBilling.Limit(json: json ~> "limit"),
                      unitDescription: json ~> "unit_description")
    }
    
    var object: Object {
        var object:Object = ["name": name, "price": price, "unit_description": unitDescription]
        
        if let limit = self.limit {
            object["limit"] = limit.object
        }
        
        return object
    }
}


extension SigChainBilling.BillingInfo:Jsonable {
    init(json: Object) throws {
        try self.init(currentTier: SigChainBilling.PaymentTier(json: json ~> "current_tier"),
                      usage: SigChainBilling.Usage(json: json ~> "usage"))
    }
    
    var object: Object {
        return ["current_tier": currentTier.object, "usage": usage.object]
    }
}
