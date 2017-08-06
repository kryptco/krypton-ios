//
//  TeamLoadController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TeamLoadController:KRBaseController, UITextFieldDelegate {
    
    var invite:TeamInvite!
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var detailLabel:UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        detailLabel.text = ""
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)        
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        
        dispatchAfter(delay: 0.3) { 
            self.loadTeam()
        }
    }
    
    func loadTeam() {
        
        var teamIdentity:TeamIdentity
        var team:Team
        do {
            team = try Team(name: "", publicKey: invite.teamPublicKey)
            teamIdentity = try TeamIdentity(email: "", team: team)
        } catch {
            self.showError(message: "Could not generate team identity. Reason: \(error).")
            return
        }
        
        let service = HashChainService(teamIdentity: teamIdentity)
        
        do {
            try service.getTeam(using: invite) { (response) in
                switch response {
                case .error(let e):
                    self.showError(message: "Error fetching team information. Reason: \(e)")
                    return
                    
                case .result(let updatedTeam):
                    teamIdentity.team = updatedTeam

                    dispatchMain {
                        self.performSegue(withIdentifier: "showTeamInvite", sender: teamIdentity)
                    }
                }
            }

        } catch {
            self.showError(message: "Could not fetch team information. Reason: \(error).")
            return
        }

    }
    
    func showError(message:String) {
        dispatchMain {
            self.detailLabel.text = message
            self.detailLabel.textColor = UIColor.reject
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject

            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let teamInviteController = segue.destination as? TeamInvitationController,
            let teamIdentity = sender as? TeamIdentity
        {
            teamInviteController.invite = invite
            teamInviteController.teamIdentity = teamIdentity
        }
    }
    

    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}
