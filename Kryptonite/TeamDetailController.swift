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
    
    @IBOutlet weak var blocksButton:UIButton!
    @IBOutlet weak var membersButton:UIButton!
    @IBOutlet weak var hostsButton:UIButton!


    var identity:TeamIdentity!
    
    var blocks:[HashChain.Payload] = []
    var members:[Team.MemberIdentity] = []
    var hosts:[SSHHostKey] = []

    enum ViewType {
        case blocks
        case members
        case hosts
    }
    
    var viewType = ViewType.blocks
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = identity.team.name
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
        
        if #available(iOS 10.0, *) {
            let refresh = UIRefreshControl()
            refresh.tintColor = UIColor.app
            refresh.addTarget(self, action: #selector(TeamDetailController.fetchTeamUpdates), for: UIControlEvents.valueChanged)
            tableView.refreshControl = refresh
        }
        
        didUpdateTeamIdentity()
    }
    
    func didUpdateTeamIdentity() {
        dispatchMain {
            self.teamLabel.text = self.identity.team.name
            self.emailLabel.text = self.identity.email
            self.approvalWindowLabel.text = self.identity.team.policy.description
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        headerView.layer.shadowColor = UIColor.black.cgColor
        headerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        headerView.layer.shadowOpacity = 0.175
        headerView.layer.shadowRadius = 3
        headerView.layer.masksToBounds = false
        
        loadNewLogs()
        fetchTeamUpdates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    dynamic func fetchTeamUpdates() {
        do {
            try HashChainService(teamIdentity: identity).getVerifiedTeamUpdates { (result) in
                
                if #available(iOS 10.0, *) {
                    self.tableView.refreshControl?.endRefreshing()
                }
                
                switch result {
                case .error(let e):
                    self.showWarning(title: "Error", body: "Could not fetch new team updates. \(e).")
                    
                case .result(let updatedTeam):
                    self.identity.team = updatedTeam
                    try? KeyManager.setTeam(identity: self.identity)
                    self.didUpdateTeamIdentity()
                    
                    self.loadNewLogs()
                }
            }
        } catch {
            self.showWarning(title: "Error", body: "Could attempting to fetch new team updates. \(error).")
        }
    }
    
    func loadNewLogs() {
        
        do {
            let blockManager = HashChainBlockManager(team: identity.team)
            
            self.blocks = try blockManager.fetchAll().map {
                try HashChain.Payload(jsonString: $0.payload)
            }
            
            self.members = try blockManager.fetchAll()
            
            self.hosts = try blockManager.fetchAll()
            
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

    // MARK: Changing View Type
    
    @IBAction func blocksTapped() {
        let type = ViewType.blocks
        showCells(for: type)
        viewType = type
        loadNewLogs()
    }
    
    @IBAction func membersTapped() {
        let type = ViewType.members
        showCells(for: type)
        viewType = type
        loadNewLogs()
    }
    
    @IBAction func hostsTapped() {
        let type = ViewType.hosts
        showCells(for: type)
        viewType = type
        loadNewLogs()
    }

    
    func showCells(for type:ViewType) {
        dispatchMain {
            self.tableView.reloadData()
        }

        switch type {
        case .blocks:
            membersButton.alpha = 0.5
            hostsButton.alpha = 0.5
            blocksButton.alpha = 1.0
        case .members:
            blocksButton.alpha = 0.5
            hostsButton.alpha = 0.5
            membersButton.alpha = 1.0
            
        case .hosts:
            membersButton.alpha = 0.5
            blocksButton.alpha = 0.5
            hostsButton.alpha = 1.0

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
        switch viewType {
        case .blocks:
            return blocks.count
        case .members:
            return members.count
        case .hosts:
            return hosts.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch viewType {
        case .blocks:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeamEventLogCell") as! TeamEventLogCell
            cell.set(payload: blocks[indexPath.row], index: indexPath.row, count: blocks.count)
            
            return cell
            
        case .members:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeamMemberCell") as! TeamMemberCell
            cell.set(member: members[indexPath.row])
            
            return cell
            
        case .hosts:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SSHHostKeyCell") as! SSHHostKeyCell
            cell.set(host: hosts[indexPath.row])
            
            return cell

        }

    }

}

extension Team.PolicySettings {
    var description:String {
        if let approvalSeconds = temporaryApprovalSeconds {            
            return TimeInterval(approvalSeconds).timeAgo(suffix: "")
        } else {
            return "unset"
        }
    }
}

extension HashChain.Payload {

    var eventLogDetails:(title:String, detail:String) {
        switch self {
        case .read(let read):
            return ("read", "get " + (read.lastBlockHash?.toBase64() ?? "first block"))
            
        case .create(let create):
            return ("create chain", "started team \"\(create.teamInfo.name)\"")
            
        case .append(let append):
            switch append.operation {
            case .inviteMember(let invite):
                return ("invite member", "invitation \(invite.noncePublicKey.toBase64())")

            case .acceptInvite(let member):
                return ("accept invite", "\(member.email) joined")
            
            case .addMember(let member):
                return ("add member", "\(member.email) was added")
            
            case .removeMember(let memberPublicKey):
                return ("remove member", "\(memberPublicKey.toBase64()) removed")
                
            case .cancelInvite(let invite):
                return ("cancel invite", "\(invite.noncePublicKey.toBase64()) canceled")

            case .setPolicy(let policy):
                return ("set policy", "temporary approval \(policy.description)")
                
            case .setTeamInfo(let teamInfo):
                return ("set team info", "team name \"\(teamInfo.name)\"")
                
            case .pinHostKey(let host):
                return ("pin ssh host key", "host \"\(host.host)\"\n\(host.displayPublicKey)")
                
            case .unpinHostKey(let host):
                return ("unpin ssh host key", "host \"\(host.host)\"\n\(host.displayPublicKey)")

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

class TeamMemberCell:UITableViewCell {
    @IBOutlet weak var email:UILabel!
    @IBOutlet weak var detail:UILabel!

    func set(member:Team.MemberIdentity) {
        email.text = member.email
        
        if member.publicKey.count >= 16 {
            detail.text = member.publicKey.subdata(in: 0 ..< 16).hexPretty
        } else {
            detail.text = member.publicKey.hexPretty
        }
    }
}

class SSHHostKeyCell:UITableViewCell {
    @IBOutlet weak var hostLabel:UILabel!
    @IBOutlet weak var keyLabel:UILabel!
    
    func set(host:SSHHostKey) {
        hostLabel.text = host.host
        keyLabel.text = (try? host.publicKey.toAuthorized()) ?? host.publicKey.toBase64()
    }
}
