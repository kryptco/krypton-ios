//
//  TeamInvitationController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamInvitationController:KRBaseController, UITextFieldDelegate {
    
    var invite:TeamInvite!
    
    @IBOutlet weak var teamNameLabel:UILabel!
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var joinButton:UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        joinButton.layer.shadowColor = UIColor.black.cgColor
        joinButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        joinButton.layer.shadowOpacity = 0.175
        joinButton.layer.shadowRadius = 3
        joinButton.layer.masksToBounds = false
        
        guard let invite = self.invite else {
            self.dismiss(animated: true, completion: nil)
            return
        }
        
        teamNameLabel.text = invite.team.name
        emailTextfield.text = invite.email
        
        setJoin(valid: !invite.email.isEmpty)
    }
    
    
    func setJoin(valid:Bool) {
        
        if valid {
            self.joinButton.alpha = 1
            self.joinButton.isEnabled = true
        } else {
            self.joinButton.alpha = 0.5
            self.joinButton.isEnabled = false
        }
    }
    
    
    @IBAction func joinTapped() {
        
        guard let email = emailTextfield.text
        else {
            self.showWarning(title: "Error", body: "Invalid team invitation or email address. Please contact your team admin.", then: {
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        // create an identity and save it
        var identity:TeamIdentity
        do {
            identity = try TeamIdentity(email: email, team: invite.team)
        } catch {
            self.showWarning(title: "Error", body: "Could not join team. Error creating team identity: \(error).")
            return
        }
        
        self.performSegue(withIdentifier: "showTeamsComplete", sender: identity)
    }
    
    @IBAction func unwindToTeamInvitation(segue: UIStoryboardSegue) {}
    
    @IBAction func cancelTapped() {
        self.dontJoinTapped()
    }

    @IBAction func dontJoinTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let text = textField.text ?? ""
        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        setJoin(valid: !txtAfterUpdate.isEmpty)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let identity = sender as? TeamIdentity else {
            log("performing segue without identity", .error)
            return
        }
        
        if let completeController = segue.destination as? TeamJoinCompleteController {
            completeController.invite = invite
            completeController.identity = identity
        }
    }
}
