//
//  Notify+Team.swift
//  Krypton
//
//  Created by Alex Grinman on 12/8/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UserNotifications

extension Notify {
    /**
        Tell the team admin theres a new block
     */
    func presentNewBlockToAdmin(signedMessage:SigChain.SignedMessage, teamName:String, subtitle:String, body:String) {
        noteMutex.lock()
        defer { noteMutex.unlock() }

        let content = UNMutableNotificationContent()
        content.title = "Team: \(teamName)"
        content.subtitle = subtitle
        content.body = body
        content.sound = UNNotificationSound.default()
        content.userInfo = [Notify.shouldPresentInAppUserInfoKey : true]
        content.categoryIdentifier = Policy.NotificationCategory.newTeamDataAlert.identifier
        
        let request = UNNotificationRequest(identifier: signedMessage.hash().toBase64() , content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

}

extension TeamIdentity {
    func getNotificationDetails(for signedMessage:SigChain.SignedMessage, dataManager: TeamDataManager) throws -> (title:String, message:String) {
        
        enum NotificationDetailsError:Error {
            case notMainChainAppendBlock
            case noSuchMember
            case noSuchAdmin
        }
        
        guard   let body = try? SigChain.Message(jsonString: signedMessage.message).body,
                case .main(.append(let appendBlock)) = body
        else {
            throw NotificationDetailsError.notMainChainAppendBlock
        }

        switch appendBlock.operation {
        case .invite(let invite):
            switch invite {
            case .direct(let direct):
                return ("", "Adding new member \(direct.email)")
                
            case .indirect(let indirect):
                switch indirect.restriction {
                case .domain(let domain):
                    return ("", "New @\(domain)-only invitation link created")
                case .emails(let emails):
                    return ("", "Invitation created for \( emails.joined(separator: ", "))")
                }
            }
            
        case .acceptInvite(let member):
            return ("", "\(member.email) joined the team")
            
        case .leave:
            guard let member = try dataManager.fetchDeletedMemberIdentity(for: signedMessage.publicKey)
            else {
                throw NotificationDetailsError.noSuchMember
            }
            
            return ("", "\(member.email) left the team")

        case .remove(let memberPublicKey):
            guard let member = try dataManager.fetchDeletedMemberIdentity(for: memberPublicKey)
            else {
                throw NotificationDetailsError.noSuchMember
            }
            
            return ("", "\(member.email) was removed from the team")
        
        case .closeInvitations:
            return ("", "Closed outstanding team invitations")

        case .setPolicy(let policy):
            return ("", "Auto-approval policy now set to \(policy.description)")
            
        case .setTeamInfo(let teamInfo):
            return ("", "Team name changed to \"\(teamInfo.name)\"")
            
        case .pinHostKey(let host):
            return ("", "Added shared host \(host.host)")
            
        case .unpinHostKey(let host):
            return ("", "Removed shared host \(host.host)")

        case .addLoggingEndpoint:
            return ("", "Audit logging enabled")
            
        case .removeLoggingEndpoint:
            return ("", "Audit logging disabled")

        case .promote(let adminPublicKey):
            guard   try dataManager.isAdmin(for: adminPublicKey),
                    let admin = try dataManager.fetchMemberIdentity(for: adminPublicKey)
            else {
                throw NotificationDetailsError.noSuchAdmin
            }
            
            if adminPublicKey == self.publicKey {
                return ("", "you have been made an admin")
            }

            return ("", "\(admin.email) has been made an admin")

            
        case .demote(let memberPublicKey):
            guard  let member = try dataManager.fetchMemberIdentity(for: memberPublicKey)
            else {
                throw NotificationDetailsError.noSuchAdmin
            }

            if memberPublicKey == self.publicKey {
                return ("", "you are no longer an admin")
            }

            return ("", "\(member.email) is no longer an admin")
        }
    }
}
