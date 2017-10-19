//
//  TeamApprovalContentController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/19/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TeamApprovalContentController: UIViewController {
    
    @IBOutlet weak var actionLabel:UILabel!
    @IBOutlet weak var descriptionLabel:UILabel!

    var identity:TeamIdentity?
    var requestBody:RequestBody?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clear()
    }
    
    func setData() {
        guard let identity = identity, let requestBody = requestBody else {
            //TODO handle error
            clear()
            return
        }
        
        switch requestBody {
        case .readTeam:
            actionLabel.text = "Read Team for 1 hr"
            descriptionLabel.text = "Allow this device to read your team data for 1 hour?"
            
        case .decryptLog:
            actionLabel.text = "Read Team Logs"
            descriptionLabel.text = "Allow this device to read your team member's log data?"
            
        case .teamOperation(let teamOp):
            
            enum TeamOperationError:Error {
                case noSuchMember
                case noSuchAdmin
            }
            
            do {
                switch teamOp.operation {
                case .invite:
                    actionLabel.text = "New Invitation Link"
                    descriptionLabel.text = "Create a new invitation link? Anyone with this link will be able to join your team."
                    
                case .cancelInvite:
                    actionLabel.text = "Expire Invitation"
                    descriptionLabel.text = "Remove all previous invitation links? All outstanding invitation links will no longer work."
                    
                case .removeMember(let memberPublicKey):
                    
                    guard let member = try identity.dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                        throw TeamOperationError.noSuchMember
                    }
                    
                    actionLabel.text = "Remove \(member.email)"
                    actionLabel.textColor = UIColor.reject
                    descriptionLabel.text = "Remove \(member.email) with identity \(memberPublicKey.toBase64()) from your team?"
                    
                case .setPolicy(let policy):
                    actionLabel.text = "Auto-approval window: \(policy.description)"
                    descriptionLabel.text = "Change your team's auto-approval window to be \(policy.description)?"
                    
                case .setTeamInfo(let info):
                    actionLabel.text = "Team name: \(info.name)"
                    descriptionLabel.text = "Change your team's name to be \"\(info.name)\"?"
                    
                case .pinHostKey(let host):
                    actionLabel.text = "Pin \(host.host)"
                    descriptionLabel.text = "Pin \"\(host.host)\" to public-key: \(host.displayPublicKey)"
                    
                case .unpinHostKey(let host):
                    actionLabel.text = "Remove pinned \(host.host)"
                    actionLabel.textColor = UIColor.reject
                    descriptionLabel.text = "Remove pinned \"\(host.host)\" from public-key: \(host.displayPublicKey)"
                    
                case .addLoggingEndpoint(let endpoint):
                    actionLabel.text = "Turn on \(endpoint.displayDescription) Logging"
                    descriptionLabel.text = "Enable \(endpoint.displayDescription) audit-logging for your team? All team member's SSH and Git signature logs will be available to team admins."
                    
                case .removeLoggingEndpoint(let endpoint):
                    actionLabel.text = "Turn off \(endpoint.displayDescription) Logging"
                    actionLabel.textColor = UIColor.reject
                    descriptionLabel.text = "Disable \(endpoint.displayDescription) audit-logging on your team? Team member's future SSH and Git signature logs will NO longer be available."
                    
                case .addAdmin(let memberPublicKey):
                    guard let member = try identity.dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                        throw TeamOperationError.noSuchMember
                    }
                    
                    actionLabel.text = "Promote \(member.email) to Admin"
                    actionLabel.textColor = UIColor.app
                    descriptionLabel.text = "Make \(member.email) with identity \(memberPublicKey.toBase64()) a team admin? Admins can modify all team data."
                    
                case .removeAdmin(let memberPublicKey):
                    guard let member = try identity.dataManager.fetchMemberIdentity(for: memberPublicKey) else {
                        throw TeamOperationError.noSuchMember
                    }
                    
                    guard try identity.dataManager.isAdmin(for: member.publicKey) else {
                        throw TeamOperationError.noSuchAdmin
                    }
                    
                    actionLabel.text = "Remove Admin \(member.email)"
                    actionLabel.textColor = UIColor.reject
                    descriptionLabel.text = "Remove admin privileges from \(member.email) with identity \(memberPublicKey.toBase64())? \(member.email) will still remain a member on your team."
                }
                
            } catch TeamOperationError.noSuchMember {
                let (action, description) = ("No Such Member", "Specified identity is not a nember of the team.")
                actionLabel.text = "Error: \(action)"
                actionLabel.textColor = UIColor.reject
                descriptionLabel.text = description
                
            } catch TeamOperationError.noSuchAdmin {
                let (action, description) = ("No Such Admin", "Specified member is not an admin of the team.")
                actionLabel.text = "Error: \(action)"
                actionLabel.textColor = UIColor.reject
                descriptionLabel.text = description
            } catch {
                actionLabel.text = "Error"
                actionLabel.textColor = UIColor.reject
                descriptionLabel.text = "\(error)"
            }
        default:
            clear()
            return
        }

    }
    
    func clear() {
        actionLabel.text = "--"
        descriptionLabel.text = "--"
    }
}
