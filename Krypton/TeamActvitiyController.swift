//
//  TeamActvitiyController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamActivityController: KRBaseTableController {

    
    var identity:TeamIdentity!    
    var blocks:[SigChain.SignedMessage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Team Activity"
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return blocks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamEventLogCell") as! TeamEventLogCell
        
        let signedMessage = blocks[indexPath.row]

        do {
            let message = try SigChain.Message(jsonString: signedMessage.message)
            let time = Date(timeIntervalSince1970: Double(message.header.utcTime)).toShortTimeString()
            
            try identity.dataManager.withTransaction {
                var signer:String
                if let member = try $0.fetchMemberIdentity(for: signedMessage.publicKey.bytes) {
                    signer = member.email
                } else if let member = try $0.fetchDeletedMemberIdentity(for: signedMessage.publicKey.bytes) {
                    signer = member.email
                } else if case .main(.append(let block)) = message.body, case .acceptInvite(let identity) = block.operation {
                    signer = "\(identity.email) invited"
                } else {
                    throw SigChain.Errors.memberDoesNotExist
                }
                
                let (title, detail) = try self.eventLogDetails(for: message, signer: signedMessage.publicKey.bytes, dataManager: $0)
                cell.set(title: title, detail: detail, signer: signer, time: time, index: indexPath.row, count: blocks.count)
            }
            
        } catch {
            cell.set(error: error, signer: signedMessage.publicKey.toBase64(), time: "--", index: indexPath.row, count: blocks.count)
        }
        
        return cell
    }
    
    func eventLogDetails(for message:SigChain.Message, signer:SodiumSignPublicKey, dataManager:TeamDataManager) throws -> (title:String, detail:String) {
        switch message.body {
        case .main(let mainChain):
            switch mainChain {
            case .read(let readRequest):
                return ("read", "get \(readRequest.teamPointer)")
            case .create(let genesisBlock):
                return ("create chain", "start team \"\(genesisBlock.teamInfo.name)\"\nby creator \(genesisBlock.creator.email)")
            case .append(let append):
                switch append.operation {
                case .invite(let invite):
                    switch invite {
                    case .direct(let direct):
                        return ("direct invitation", "for \(direct.email)")
                        
                    case .indirect(let indirect):
                        let title = "indirect invitation"
                        
                        var restriction:String
                        switch indirect.restriction {
                        case .domain(let domain):
                            restriction = "@\(domain)-only"
                        case .emails(let emails):
                            restriction = "for \(emails.joined(separator: ", ")) only"
                        }
                        
                        return (title, "restriction: \(restriction)")
                    }
                    
                case .acceptInvite(let member):
                    return ("accept invite", "\(member.email) joined the team")
                    
                case .leave:
                    guard let member = try dataManager.fetchDeletedMemberIdentity(for: signer) else {
                        throw SigChain.Errors.memberDoesNotExist
                    }
                    
                    return ("leave team", "\(member.email) left the team")
                    
                case .remove(let memberPublicKey):
                    guard let member = try dataManager.fetchDeletedMemberIdentity(for: memberPublicKey) else {
                        throw SigChain.Errors.memberDoesNotExist
                    }

                    return ("remove member", "\(member.email) was removed from the team")
                    
                case .closeInvitations:
                    return ("close all invitations", "")
                    
                case .setPolicy(let policy):
                    return ("set policy", "temporary approval \(policy.description)")
                    
                case .setTeamInfo(let teamInfo):
                    return ("set team info", "team name \"\(teamInfo.name)\"")
                    
                case .pinHostKey(let host):
                    return ("pin ssh host key", "host \"\(host.host)\"\n\(host.displayPublicKey)")
                    
                case .unpinHostKey(let host):
                    return ("unpin ssh host key", "host \"\(host.host)\"\n\(host.displayPublicKey)")
                    
                case .addLoggingEndpoint(let endpoint):
                    return ("enable logging", "endpoint \(endpoint)")
                    
                case .removeLoggingEndpoint(let endpoint):
                    return ("disable logging", "endpoint \(endpoint)")
                    
                case .promote(let admin):
                    // look for the member in active and deleted
                    if let member = try dataManager.fetchMemberIdentity(for: admin) {
                        return ("promote", "\(member.email) promoted to admin")
                    }

                    if let member = try dataManager.fetchDeletedMemberIdentity(for: admin) {
                        return ("promote", "\(member.email) promoted to admin")
                    }

                    throw SigChain.Errors.memberDoesNotExist

                    
                case .demote(let admin):
                    // look for the member in active and deleted
                    if let member = try dataManager.fetchMemberIdentity(for: admin) {
                        return ("demote", "\(member.email) demoted to member")
                    }
                    
                    if let member = try dataManager.fetchDeletedMemberIdentity(for: admin) {
                        return ("demoted", "\(member.email) demoted to member")
                    }
                    
                    throw SigChain.Errors.memberDoesNotExist
                }
            }
            
        case .log(let logChain):
            switch logChain {                
            case .create(let logGenesisBlock):
                return ("create log chain", "started encrypted log chain (\(logGenesisBlock.wrappedKeys.count) admins)")
                
            case .append(let appendLogBlock):
                switch appendLogBlock.operation {
                case .addWrappedKeys(let wrappedKeys):
                    return ("give new admin(s) log access", "\(wrappedKeys.count) admins")
                case .rotateKey(let wrappedKeys):
                    return ("rotate log access keys", "rotated for \(wrappedKeys.count) admins")
                case .encryptLog:
                    return ("write new encrypted log", "")
                }
            case .read:
                return ("read logs", "")
                
            }
        case .readToken(let readToken):
            switch readToken {
            case .time(let timeToken):
                let expires = Date(timeIntervalSince1970: TimeInterval(timeToken.expiration)).toShortTimeString()
                return ("issue time read token", "expires: \(expires))")
            }
        case .emailChallenge(let emailChallenge):
            return ("solve email challenge", "challenge: \(emailChallenge.nonce.toBase64())")
            
        case .pushSubscription(let pushSubscription):
            switch pushSubscription.action {
            case .subscribe:
                return ("push subscription", "subscribe")
            case .unsubscribe:
                return ("push subscription", "unsubscribe")
            }
        case .readBillingInfo:
            return ("read billing info", "")
        }
        
    }

}

extension SigChain.TeamPointer:CustomStringConvertible {
    var description:String {
        switch self {
        case .publicKey(let pub):
            return "public key \(pub.toBase64())"
        case .lastBlockHash(let hash):
            return "block hash \(hash.toBase64())"
        }
    }
}


class TeamEventLogCell:UITableViewCell {
    @IBOutlet weak var eventName:UILabel!
    @IBOutlet weak var timeLabel:UILabel!
    @IBOutlet weak var eventDetail:UILabel!
    @IBOutlet weak var signerLabel:UILabel!

    @IBOutlet weak var topLine:UIView!
    @IBOutlet weak var bottomLine:UIView!
    @IBOutlet weak var dot:UIView!

    func set(title:String, detail:String, signer:String, time:String, index:Int, count:Int) {
        eventName.text = title
        eventDetail.text = detail
        timeLabel.text = time
        signerLabel.text = signer
        
        drawLines(for: index, count: count, color: UIColor.app)
    }
    
    func set(error:Error, signer:String, time:String, index:Int, count:Int) {
        eventName.text = "Error"
        eventDetail.text = "\(error)"
        timeLabel.text = time
        signerLabel.text = signer

        drawLines(for: index, count: count, color: UIColor.reject)
    }
    
    func drawLines(for index:Int, count:Int, color:UIColor) {
        dot.backgroundColor = color
        topLine.backgroundColor = color
        bottomLine.backgroundColor = color
        
        switch index {
        case let x where x == 0 && x == count - 1:
            bottomLine.isHidden = true
            topLine.isHidden = true
        case 0:
            bottomLine.isHidden = false
            topLine.isHidden = true
        case count - 1:
            bottomLine.isHidden = true
            topLine.isHidden = false
        default:
            bottomLine.isHidden = false
            topLine.isHidden = false
        }
    }
}
