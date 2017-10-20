//
//  Request+Notify.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/23/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension Request {
    
    /**
        Get a notification subtitle and body message
     */
    func notificationDetails()  -> (subtitle:String, body:String) {
        switch self.body {
        case .ssh(let sshSign):
            return ("SSH Login", sshSign.display)
        case .git(let gitSign):
            let git = gitSign.git
            return (git.subtitle + " Signature", git.shortDisplay)
        case .me:
            return ("Identity Request", "Public key exported")
        case .unpair:
            return ("Unpair", "Device has been unpaired")
        case .noOp:
            return ("", "Ping")
        case .createTeam(let create):
            return ("Team", "Do you want to create team \(create.teamInfo.name)?")
        case .readTeam:
            return ("Team", "Trust this computer to load team data?")
        case .teamOperation(let op):
            return ("Team", op.operation.summary)
        case .decryptLog:
            return ("Team", "Decrypt Logs?")
        }
    }
}

extension RequestableTeamOperation {
    
    var summary:String {
        switch self {
        case .invite:
            return "Create new invitation link?"
            
        case .cancelInvite:
            return "Expire invitation link?"
            
        case .removeMember:
            return "Remove team member?"
            
        case .setPolicy(let policy):
            return "Change auto-approval window to \(policy.description)?"
            
        case .setTeamInfo(let info):
            return "Change team name to \(info.name)?"
            
        case .pinHostKey(let host):
            return "Pin \"\(host.host)\" to public-key: \(host.displayPublicKey)"
            
        case .unpinHostKey(let host):
            return "Remove pinned \"\(host.host)\" from public-key: \(host.displayPublicKey)"
            
        case .addLoggingEndpoint(let endpoint):
            return "Enable \(endpoint.displayDescription) audit-logging for your team?"
            
        case .removeLoggingEndpoint(let endpoint):
            return "Disable \(endpoint.displayDescription) audit-logging on your team? Team member's future SSH and Git signature logs will NO longer be available."
            
        case .addAdmin:
            return "Promote team member to admin privileges?"
            
        case .removeAdmin:
            return "Remove admin privileges from team member?"
        }

    }
}
