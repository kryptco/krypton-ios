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
    var teamIdentity:TeamIdentity!

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
        
        teamNameLabel.text = teamIdentity.team.name
        emailTextfield.text = try? KeyManager.getMe()
        emailTextfield.isEnabled = true
        setJoin(valid: !(emailTextfield.text ?? "").isEmpty)
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
            self.showWarning(title: "Error", body: "Invalid email address. Please enter a valid team email", then: {
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        // set the team identity's email
        teamIdentity.email = email
        
        self.performSegue(withIdentifier: "showTeamsComplete", sender: nil)
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
        if let completeController = segue.destination as? TeamJoinCompleteController {
            completeController.invite = invite
            completeController.teamIdentity = teamIdentity
        }
    }
}
