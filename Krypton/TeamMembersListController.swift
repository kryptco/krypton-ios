//
//  TeamMembersListController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import PGPFormat

class TeamMemberListController: KRBaseTableController {
    
    var identity:TeamIdentity!
    var members:[SigChain.Identity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setKrLogo()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 65
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamMemberCell") as! TeamMemberCell
        
        let isAdmin = (try? identity.dataManager.withTransaction{
                return try $0.isAdmin(for: members[indexPath.row].publicKey)
            }) ?? false
        cell.set(index: indexPath.row, member: members[indexPath.row], isAdmin: isAdmin)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let member = members[indexPath.row]
        
        self.performSegue(withIdentifier: "showMemberDetail", sender: member)
    }
    
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let member = members[indexPath.row]
        
        // dont remove self from here
        if member.publicKey == identity.publicKey {
            return false
        }

        
        if  let isAdmin = (try? identity.dataManager.withTransaction { return try identity.isAdmin(dataManager: $0) }) as Bool?,
                isAdmin
        {
            return true
        }
        
        return false
    }
    
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Remove"
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            let member = members[indexPath.row]
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .remove(member.publicKey))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
            }, title: "Remove Member", onSuccess: {
                self.members.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .right)
            })
            
        } else if editingStyle == .insert {
            return
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let memberController = segue.destination as? TeamMemberController,
            let member = sender as? SigChain.Identity
        {
            memberController.identity = identity
            memberController.member = member
        }
    }
}

class TeamMemberCell:UITableViewCell {
    @IBOutlet weak var email:UILabel!
    @IBOutlet weak var indexLabel:UILabel!
    @IBOutlet weak var roleView:UIView!

    func set(index:Int, member:SigChain.Identity, isAdmin:Bool = false) {
        indexLabel.text = "\(index+1)."
        email.text = member.email
        roleView.isHidden = !isAdmin
    }
}


class TeamMemberController: KRBaseTableController {

    @IBOutlet weak var emailLabel:UITextField!
    @IBOutlet weak var idLabel:UILabel!
    @IBOutlet weak var headerView:UIView!
    @IBOutlet weak var removeButton:UIButton!
    @IBOutlet weak var demoteButton:UIButton!
    
    var identity:TeamIdentity!
    var member:SigChain.Identity!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setKrLogo()
        
        log(member.publicKey.toBase64(), .warning)
    }
    
    func loadMemberData() {
        emailLabel.isEnabled = false
        emailLabel.text = member.email
        
        let (memberIsAdmin, weAreAdmin) = (try? identity.dataManager.withTransaction {
                return try ($0.isAdmin(for: member.publicKey), $0.isAdmin(for: identity.publicKey))
            }) ?? (false, false)

        
        if  memberIsAdmin {
            demoteButton.setTitleColor(UIColor.reject, for: .normal)
            demoteButton.setBorder(color: UIColor.reject, cornerRadius: 2.0, borderWidth: 1.0)
            demoteButton.setTitle("Change to member", for: .normal)
            idLabel.text = "Admin"

        } else {
            demoteButton.setTitleColor(UIColor.app, for: .normal)
            demoteButton.setBorder(color: UIColor.app, cornerRadius: 2.0, borderWidth: 1.0)
            demoteButton.setTitle("Change to admin", for: .normal)
            idLabel.text = "Member"
        }
        
        if weAreAdmin {
            if member.publicKey == identity.publicKey {
                removeButton.isHidden = true
            } else {
                removeButton.isHidden = false
            }
        } else {
            demoteButton.isHidden = true
            removeButton.isHidden = true
        }
        
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        headerView.layer.shadowColor = UIColor.black.cgColor
        headerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        headerView.layer.shadowOpacity = 0.175
        headerView.layer.shadowRadius = 3
        headerView.layer.masksToBounds = false
        
        loadMemberData()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    @IBAction func removeTapped() {
        self.askConfirmationIn(title: "Remove member?", text: "Are you sure you want to remove this team member?", accept: "Yes", cancel: "Cancel")
        { (didConfirm) in
            
            guard didConfirm else {
                return
            }
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .remove(self.member.publicKey))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
            }, title: "Remove Member", onSuccess: {
                dispatchMain { self.navigationController?.popToRootViewController(animated: true) }
            })
        }
    }
    
    @IBAction func demoteTapped() {
        // if member is an admin
        if let isAdmin = (try? identity.dataManager.withTransaction{ return try $0.isAdmin(for: member.publicKey) }),
            isAdmin
        {
            doDemote()
        } else {
            doPromote()
        }
    }
    
    func doPromote() {
        self.askConfirmationIn(title: "Promote to admin?", text: "Are you sure you want give this member admin priviledges?", accept: "Yes", cancel: "Cancel")
        { (didConfirm) in
            
            guard didConfirm else {
                return
            }
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .promote(self.member.publicKey))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
            }, title: "Change to admin", onSuccess: {
                dispatchMain { self.loadMemberData() }
            })
        }
    }
    
    func doDemote() {
        self.askConfirmationIn(title: "Remove admin priviledges?", text: "Are you sure you want revoke this admin's priviledges?", accept: "Yes", cancel: "Cancel")
        { (didConfirm) in
            
            guard didConfirm else {
                return
            }
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .demote(self.member.publicKey))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
            }, title: "Change to member", onSuccess: {
                dispatchMain { self.loadMemberData() }
            })
        }
    }
    
    @IBAction func copySSHTapped() {
        let key = (try? member.sshPublicKey.toAuthorized()) ?? member.sshPublicKey.toBase64()
        let share = UIActivityViewController(activityItems: [key], applicationActivities: nil)
    
        present(share, animated: true, completion: nil)
    }
    
    @IBAction func copyPGPTapped() {
        let key = AsciiArmorMessage(packetData: member.pgpPublicKey, blockType: .publicKey, comment: Properties.defaultPGPMessageComment).toString()
        let share = UIActivityViewController(activityItems: [key], applicationActivities: nil)
        present(share, animated: true, completion: nil)
    }
    
}
