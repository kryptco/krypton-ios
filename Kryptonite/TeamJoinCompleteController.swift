//
//  TeamJoinCompleteController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamJoinCompleteController:KRBaseController {
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var joiningLabel:UILabel!
    @IBOutlet weak var teamNameLabel:UILabel!
    
    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewUp:NSLayoutConstraint!
    @IBOutlet weak var resultViewDown:NSLayoutConstraint!


    var invite:TeamInvite!
    var identity:Identity!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        teamNameLabel.text = invite.team.name
        
        resultViewUp.priority = 750
        resultViewDown.priority = 999
        self.view.layoutIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        
        dispatchAfter(delay: 2.0) { 
            self.finishJoinTeam()
        }
    }
    
    func finishJoinTeam() {
        
        // 1. save the identity
        do {
            try IdentityManager.shared.save(identity: identity)
        } catch {
            self.showWarning(title: "Error", body: "Could not save team identity: \(error).", then: {
                self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
            })
            
            return
        }
        
        // 2. send team invite response
        
        // 3. show success
        
        UIView.animate(withDuration: 0.3, animations: {
            self.joiningLabel.text = "JOINED"
            self.arcView.alpha = 0
            self.resultViewUp.priority = 999
            self.resultViewDown.priority = 750
            self.view.layoutIfNeeded()

        }) { (_) in
            self.checkBox.toggleCheckState(true)
        }
    }
    
    @IBAction func doneTapped() {
        self.performSegue(withIdentifier: "dismissJoinTeam", sender: nil)

    }
    
}
