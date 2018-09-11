//
//  Policy+Allow.swift
//  Krypton
//
//  Created by Alex Grinman on 11/12/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import AwesomeCache

extension Policy {
    
    /// Notification Action Identifiers
    enum Action:String {
        case approve = "approve_identifier"
        case temporaryThis = "approve_temp_this_identifier"
        case temporaryAll = "approve_temp_all_identifier"
        case dontAskAgain = "approve_all_identifier"
        case reject = "reject_identifier"
        
        var identifier:String {
            return self.rawValue
        }
        
        // helper to know if action was allowed or rejected
        var isAllowed:Bool {
            switch self {
            case .approve, .temporaryThis, .temporaryAll, .dontAskAgain:
                return true
            case .reject:
                return false
            }
        }
    }
    
    /// Notification Category Types
    enum NotificationCategory:String {
        case autoAuthorized = "auto_authorized_identifier"
        case authorizeWithTemporal = "authorize_temporal_identifier"
        case authorizeWithTemporalThis = "authorize_temporal_this_identifier"
        case authorize = "authorize_identifier"
        case authorizeSimple = "authorize_simple_identifier"

        case newTeamData = "new_team_data"
        case newTeamDataAlert = "new_team_data_alert"

        case none = ""
        
        var identifier:String {
            return self.rawValue
        }
    }

}


