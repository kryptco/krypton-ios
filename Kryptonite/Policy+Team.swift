//
//  Policy+Team.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/6/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

struct TemporaryApprovalTime {
    let description:String
    let short:String
    let value:TimeInterval
}
extension Policy {
    
    static var temporaryApprovalInterval:TemporaryApprovalTime {
        
        var approvalSeconds:TimeInterval
        
        // check if we have a team
        if  let teamIdentity = (try? KeyManager.getTeamIdentity()) as? TeamIdentity,
            let teamApprovalSeconds = teamIdentity.team.policy.temporaryApprovalSeconds
        {
            approvalSeconds = Double(teamApprovalSeconds)
        } else {
            approvalSeconds = Properties.Interval.threeHours.rawValue
        }
        
        let shifted = Date().shifted(by: approvalSeconds)
        let description = shifted.timeAgoLong(suffix: "")
        let short = shifted.timeAgo(suffix: "")
        
        return TemporaryApprovalTime(description: description, short: short, value: approvalSeconds)
    }
}
