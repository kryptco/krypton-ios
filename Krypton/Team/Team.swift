//
//  Team.swift
//  Krypton
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct Team:Jsonable {
        
    var info:SigChain.TeamInfo
    var policy:SigChain.Policy
    var loggingEndpoints = Set<SigChain.LoggingEndpoint>()
    
    var name:String {
        return info.name
    }
    
    var commandEncryptedLoggingEnabled:Bool {
        return loggingEndpoints.index(of: SigChain.LoggingEndpoint.commandEncrypted) != nil
    }

    init(info:SigChain.TeamInfo, policy:SigChain.Policy = SigChain.Policy(temporaryApprovalSeconds: nil), loggingEndpoints:Set<SigChain.LoggingEndpoint> = [])
    {
        self.info = info
        self.policy = policy
        self.loggingEndpoints = loggingEndpoints
    }
    
    init(json: Object) throws {
        try self.init(info: SigChain.TeamInfo(json: json ~> "info"),
                      policy: SigChain.Policy(json: json ~> "policy"),
                      loggingEndpoints: Set<SigChain.LoggingEndpoint>([SigChain.LoggingEndpoint](json: json ~> "logging_endpoints")))
    }
    
    var object: Object {
        return ["info": info.object,
                "policy": policy.object,
                "logging_endpoints": loggingEndpoints.map({ $0 }).objects ]        
    }
    

}
