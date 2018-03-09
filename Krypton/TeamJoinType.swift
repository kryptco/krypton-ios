//
//  TeamJoinType.swift
//  Krypton
//
//  Created by Alex Grinman on 11/29/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

struct CreateFromAppSettings {
    let name:String
    var auditLoggingEnabled = false
    var autoApprovalInterval:TimeInterval = 0
    var hosts:[SSHHostKey] = []
    
    init(name:String) {
        self.name = name
    }
}

enum TeamJoinType {
    case directInvite(TeamIdentity)
    case indirectInvite(SigChain.IndirectInvitation.Secret)
    case createFromApp(CreateFromAppSettings)
}
