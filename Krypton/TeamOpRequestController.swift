//
//  File.swift
//  Krypton
//
//  Created by Alex Grinman on 11/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamOpRequestController:UIViewController {
        
    @IBOutlet weak var teamLabel:UILabel!
    @IBOutlet weak var actionLabel:UILabel!
    @IBOutlet weak var descriptionLabel:UILabel!
    
    @IBOutlet weak var teamView:UIView!
    @IBOutlet weak var indicatorView:UIView!

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    enum TeamOperationError:Error {
        case noSuchMember
        case noSuchAdmin
    }
    
    func setSuccessIndicator(success:Bool) {
        let color = success ? UIColor.app : UIColor.reject
        indicatorView.backgroundColor = color
    }

    func set(teamName:String, readTeamRequest:ReadTeamRequest) {
        teamLabel.text = teamName
        actionLabel.text = "Trust this computer to load team data"
        descriptionLabel.text = "This computer will be able to access team data and audit logs for the next 6 hours."

    }
    func set(teamName:String, decryptLogRequest:LogDecryptionRequest) {
        teamLabel.text = teamName
        actionLabel.text = "Trust this computer to load audit logs"
        descriptionLabel.text = "This device will be able to access team audit logs for the next 6 hours."
    }
    
    func set(identity:TeamIdentity, teamOperationRequest:TeamOperationRequest, dataManager: TeamDataManager) throws {
        let teamName = try dataManager.fetchTeam().name
        teamLabel.text = teamName
        
        switch teamOperationRequest.operation {
        case .indirectInvite(let restriction):
            actionLabel.text = "New Invitation Link"
            
            switch restriction {
            case .domain(let domain):
                descriptionLabel.text = "Restricted to @\(domain) email addresses only."
            case .emails(let emails):
                descriptionLabel.text = "Restricted to the following users: \(emails.joined(separator: ", "))."
            }
        case .directInvite(let direct):
            actionLabel.text = "New Invitation for \"\(direct.email)\""
            descriptionLabel.text = "Create an invitation for \(direct.email) to join your team."

        case .closeInvitations:
            actionLabel.text = "Close Invitations"
            descriptionLabel.text = "Closes all outstanding invitations."
            
        case .leave:
            actionLabel.text = "Leave Team"
            descriptionLabel.text = "You will no longer have access to team \(teamName)."
            setSuccessIndicator(success: false)

        case .remove(let memberPublicKey):
            guard let member = try dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                throw TeamOperationError.noSuchMember
            }
            
            actionLabel.text = "Remove: \(member.email)"
            descriptionLabel.text = "\(member.email) will no longer be part of your team."
            
            setSuccessIndicator(success: false)
            
        case .setPolicy(let policy):
            actionLabel.text = "Approval Window: \(policy.description)"
            descriptionLabel.text = "All team members can now auto-approve requests for \(policy.description)."
            
        case .setTeamInfo(let info):
            actionLabel.text = "Team name: \"\(info.name)\""
            descriptionLabel.text = "Your team's name will be \"\(info.name)\"."
            
        case .pinHostKey(let host):
            actionLabel.text = "Add Host: \(host.host)"
            descriptionLabel.text = "Team members will use the known host \"\(host.host)\" with fingerprint: \(host.publicKey.fingerprint().toBase64())."
            setSuccessIndicator(success: true)

            
        case .unpinHostKey(let host):
            actionLabel.text = "Remove Host: \(host.host)"
            descriptionLabel.text = "Team members will no longer use the known host \"\(host.host)\" with fingerprint: \(host.publicKey.fingerprint().toBase64())."
            setSuccessIndicator(success: false)

            
        case .addLoggingEndpoint(let endpoint):
            switch endpoint {
            case .commandEncrypted:
                actionLabel.text = "Enabled Audit Logging (Encrypted)"
                descriptionLabel.text = "Team member's SSH and Git signature logs will be accessible to team admins. Non-admins and krypt.co do NOT have access to audit logs."
            }
            
        case .removeLoggingEndpoint(let endpoint):
            switch endpoint {
            case .commandEncrypted:
                actionLabel.text = "Disable Audit Logging"
                descriptionLabel.text = "Team member's new SSH and Git signature logs will NO longer be recorded for admins."
                setSuccessIndicator(success: false)

            }
            
        case .promote(let memberPublicKey):
            guard let member = try dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                throw TeamOperationError.noSuchMember
            }
            
            actionLabel.text = "Promote: \(member.email)"
            descriptionLabel.text = "Make \(member.email) a team admin. Admins can modify all team data."
            setSuccessIndicator(success: true)

            
        case .demote(let memberPublicKey):
            guard let member = try dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                throw TeamOperationError.noSuchMember
            }
            
            guard try dataManager.isAdmin(for: member.publicKey) else {
                throw TeamOperationError.noSuchAdmin
            }
            
            actionLabel.text = "Demote: \(member.email)"
            descriptionLabel.text = "\(member.email) will no longer have team admin privileges."
            setSuccessIndicator(success: false)

        }

    }
}

