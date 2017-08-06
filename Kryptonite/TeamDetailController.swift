//
//  TeamDetailController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/22/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit
import LocalAuthentication

class TeamDetailController: KRBaseTableController {

    @IBOutlet weak var teamLabel:UILabel!
    @IBOutlet weak var emailLabel:UILabel!
    @IBOutlet weak var leaveTeamButton:UIButton!
    @IBOutlet weak var headerView:UIView!

    @IBOutlet weak var approvalWindowLabel:UILabel!
    @IBOutlet weak var unknownHostsLabel:UILabel!

    var identity:TeamIdentity!
    
    var blocks:[HashChain.Payload] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = identity.team.name
        
        teamLabel.text = identity.team.name
        emailLabel.text = identity.email
        approvalWindowLabel.text = identity.team.policy.description
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        headerView.layer.shadowColor = UIColor.black.cgColor
        headerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        headerView.layer.shadowOpacity = 0.175
        headerView.layer.shadowRadius = 3
        headerView.layer.masksToBounds = false
        
        loadNewLogs()
        
        do {
            try HashChainService(teamIdentity: identity).getVerifiedTeamUpdates { (result) in
                switch result {
                case .error(let e):
                    self.showWarning(title: "Error", body: "Could not fetch new team updates. \(e).")
                    
                case .result(let updatedTeam):
                    self.identity.team = updatedTeam.team
                    try? KeyManager.setTeam(identity: self.identity)
                    try? self.identity.team.set(lastBlockHash: updatedTeam.lastBlockHash)
                    
                    self.loadNewLogs()
                }
            }
        } catch {
            self.showWarning(title: "Error", body: "Could attempting to fetch new team updates. \(error).")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func loadNewLogs() {
        
        do {
            self.blocks = try HashChainBlockManager(team: identity.team).fetchAll().map {
                try HashChain.Payload(jsonString: $0.payload)
            }
            
            dispatchMain {
                self.tableView.reloadData()
            }
            
        } catch {
            log("error loading team blocks: \(error)", .error)
        }
    }
    
    @IBAction func leaveTeamTapped() {
        
        let message = "You will no longer have access to the team's data and your team admin will be notified that you are leaving the team. Are you sure you want to continue?"
        
        let sheet = UIAlertController(title: "Do you want to leave the \(identity.team.name) team?", message: message, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Leave Team", style: UIAlertActionStyle.destructive, handler: { (action) in
            self.leaveTeamRequestAuth()
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)

    }
    
    func leaveTeamRequestAuth() {
        authenticate { (yes) in
            guard yes else {
                return
            }
            
            do {
                try KeyManager.removeTeamIdentity()
            } catch {
                self.showWarning(title: "Error", body: "Cannot leave team: \(error)")
                return
            }
            
            dispatchMain {
                self.performSegue(withIdentifier: "showLeaveTeam", sender: nil)
            }
        }
    }
    
    func authenticate(completion:@escaping (Bool)->Void) {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        let reason = "Leave the \(identity.team.name) team?"
        
        var err:NSError?
        guard context.canEvaluatePolicy(policy, error: &err) else {
            log("cannot eval policy: \(err?.localizedDescription ?? "unknown err")", .error)
            completion(true)
            
            return
        }
        
        
        dispatchMain {
            context.evaluatePolicy(policy, localizedReason: reason, reply: { (success, policyErr) in
                completion(success)
            })
            
        }
        
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: TableView
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return blocks.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamEventLogCell") as! TeamEventLogCell
        cell.set(payload: blocks[indexPath.row], index: indexPath.row, count: blocks.count)

        return cell
    }

}

extension Team.PolicySettings {
    var description:String {
        if let approvalSeconds = temporaryApprovalSeconds {
            return Date().shifted(by: Double(approvalSeconds)).timeAgo(suffix: "")
        } else {
            return "unset"
        }
    }
}

extension HashChain.Payload {

    var eventLogDetails:(title:String, detail:String) {
        switch self {
        case .read(let read):
            return ("read_block", "get " + (read.lastBlockHash?.toBase64() ?? "first block"))
            
        case .create(let create):
            return ("create_chain", "started team \"\(create.teamInfo.name)\"")
            
        case .append(let append):
            switch append.operation {
            case .inviteMember(let invite):
                return ("invite_member", "invitation \(invite.noncePublicKey.toBase64())")

            case .acceptInvite(let member):
                return ("accept_invite", "\(member.email) joined")
            
            case .addMember(let member):
                return ("add_member", "\(member.email) was added")
            
            case .removeMember(let memberPublicKey):
                return ("remove_member", "\(memberPublicKey.toBase64()) removed")
                
            case .cancelInvite(let invite):
                return ("cancel_invite", "\(invite.noncePublicKey.toBase64()) canceled")

            case .setPolicy(let policy):
                return ("set_policy", "temporary approval \(policy.description)")
                
            case .setTeamInfo(let teamInfo):
                return ("set_team_info", "team name \"\(teamInfo.name)\"")
            }
        }
        
    }
}


class TeamEventLogCell:UITableViewCell {
    @IBOutlet weak var eventName:UILabel!
    @IBOutlet weak var eventDetail:UILabel!
    
    @IBOutlet weak var topLine:UIView!
    @IBOutlet weak var bottomLine:UIView!

    func set(payload:HashChain.Payload, index:Int, count:Int) {
        let (title, detail) = payload.eventLogDetails
        eventName.text = title
        eventDetail.text = detail
        
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




