//
//  Request+Notify.swift
//  Krypton
//
//  Created by Alex Grinman on 6/23/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension Request {
    
    /**
        Get a notification subtitle and body message
     */
    func notificationDetails(autoResponse:Bool = false)  -> (title:String, body:String) {
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
        case .hosts:
            return ("Host List Request", "Send 'user@hostname' from access logs")
        case .noOp:
            return ("", "Ping")
        case .readTeam:
            return ("Team Request", "Trust this computer to load team data")
        case .teamOperation(let op):
            return ("Team Request", op.operation.summary)
        case .decryptLog:
            return ("Team Request", "Read member audit logs")
        case .u2fRegister(let u2fRegister):
            let display = KnownU2FApplication(for: u2fRegister.appID)?.displayName ?? u2fRegister.appID
            let body = autoResponse ? "Registered successfully" : "Register Krypton for \(display)?"
            return ("\(display)", body)
        case .u2fAuthenticate(let u2fAuthenticate):
            let display = KnownU2FApplication(for: u2fAuthenticate.appID)?.displayName ?? u2fAuthenticate.appID
            let body = autoResponse ? "signed in" : "Are you trying to sign in?"
            return ("\(display)", body)
        }
    }
    
    func notificationSubtitle(for sessionDisplayName:String, autoResponse:Bool = false, isError:Bool = false) -> String {
        switch self.body {
        case .ssh, .git, .me, .unpair, .hosts, .noOp, .readTeam, .teamOperation, .decryptLog:
            
            guard autoResponse else {
                return "Request from \(sessionDisplayName)"
            }
            
            guard isError else {
                return "Approved request from \(sessionDisplayName)"
            }
            
            return "Failed request from \(sessionDisplayName)"
            
        case .u2fRegister, .u2fAuthenticate: // simplified
            return ""
        }
    }
}

extension RequestableTeamOperation {
    var summary:String {
        switch self {
        case .directInvite(let direct):
            return "Add \(direct.email)"
        case .indirectInvite(let restriction):
            switch restriction {
            case .domain(let domain):
                return "Create a @\(domain)-only invitation link"
            case .emails(let emails):
                return "Create an invitation link for: \(emails.joined(separator: ", "))"
            }            
        case .closeInvitations:
            return "Closes all open invitations"
        
        case .leave:
            return "Leave team"
            
        case .remove:
            return "Remove team member"
            
        case .setPolicy(let policy):
            return "Change auto-approval window to \(policy.description)"
            
        case .setTeamInfo(let info):
            return "Change team name to \(info.name)"
            
        case .pinHostKey(let host):
            return "Add shared host \"\(host.host)\""
            
        case .unpinHostKey(let host):
            return "Remove shared host \"\(host.host)\""
            
        case .addLoggingEndpoint(let endpoint):
            return "Enable \(endpoint.displayDescription) audit-logging"
            
        case .removeLoggingEndpoint(let endpoint):
            return "Disable \(endpoint.displayDescription) audit-logging. Future audit logs will NO longer be created."
            
        case .promote:
            return "Promote member"
            
        case .demote:
            return "Demote member"
        }

    }
}
