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

    var identity:Identity!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let count = try? IdentityManager.shared.count(), count == 1 {
            self.title = identity.team.name
        } else {
            self.title = "Team"
        }
        
        
        teamLabel.text = identity.team.name
        emailLabel.text = identity.email
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        headerView.layer.shadowColor = UIColor.black.cgColor
        headerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        headerView.layer.shadowOpacity = 0.175
        headerView.layer.shadowRadius = 3
        headerView.layer.masksToBounds = false
    }
    
    @IBAction func leaveTeamTapped() {
        
        let defaultMessage = "You will no longer have access to the team's data and your team admin will be notified that you are leaving the team."
        
        var message = defaultMessage
        if identity.usesDefaultKey == false {
            message += " Your team key pair will also be gone forever."
        }
        
        message += " Are you sure you want to continue?"
        
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
                try IdentityManager.shared.remove(identity: self.identity)
                if !self.identity.usesDefaultKey {
                    KeyManager.destroyKeyPair(for: self.identity)
                }
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

}
