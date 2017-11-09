//
//  Request+Policy.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/8/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension Request {
    var notificationCategory:Policy.NotificationCategory {
        switch self.body {
        case .me, .unpair, .noOp:
            return .none
            
        case .ssh(let signRequest):
            if let _ = signRequest.verifiedHostAuth {
                return .authorizeWithTemporalThis
            }
            
            return .authorizeWithTemporal
            
        case .git:
            return .authorizeWithTemporal
        case .hosts:
            return .authorize
        }
    }
    
    var autoNotificationCategory:Policy.NotificationCategory {
        switch self.body {
        case .hosts, .me, .unpair, .noOp:
            return .none
        case .git, .ssh:
            return .autoAuthorized
        }
    }

    
    
}
