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
    
    typealias Cents = UInt64

    struct PaymentTier {
        let name:String
        let price:Cents
        let limit:Usage
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


extension SigChainBilling.PaymentTier:Jsonable {
    init(json: Object) throws {
        try self.init(name: json ~> "name",
                      price: json ~> "price",
                      limit: SigChainBilling.Usage(json: json ~> "limit"))
    }
    
    var object: Object {
        return ["name": name, "price": price, "limit": limit.object]
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
