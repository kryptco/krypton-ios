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
    var identity:TeamIdentity!
    
    struct JoinWorkflowError:Error, CustomDebugStringConvertible  {
        let error:Error
        let action:String
        
        init(_ error:Error, action:String) {
            self.error = error
            self.action = action
        }
        var debugDescription: String {
            return "\(action). Internal message: \(error)"
        }
    }
    
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
            try KeyManager.setTeam(identity: identity)
        } catch {
            showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
            return
        }
        
        // 2. send team invite response
        let hashChainService = HashChainService(teamIdentity: identity)
        
        do {
            try hashChainService.accept(invite: invite) { result in
                switch result {
                case .error(let error):
                    self.showFailure(by: JoinWorkflowError(error, action: "Team server error response on accept invite."))
                    
                case .result:
                    // TODO verify block posted succesfully
                    
                    self.showSuccess()
                }
            }

        } catch HashChainService.Errors.needNewestBlock {
            
            // we have a newer block
            // fetch new blocks and try again
            do {
                try hashChainService.getVerifiedTeamUpdates({ (result) in
                    switch result {
                    case .error(let error):
                        self.showFailure(by: JoinWorkflowError(error, action: "Server error getting newest block on retry."))
                        
                    // new team object, update and save it
                    case .result(let updatedTeam):
                        self.identity.team = updatedTeam
                        try? KeyManager.setTeam(identity: self.identity)
                        
                        // try join team again
                        self.finishJoinTeam()
                    }
                })
            } catch {
                self.showFailure(by: JoinWorkflowError(error, action: "Failed getting newest block on retry."))
            }
            
        } catch {
            self.showFailure(by: JoinWorkflowError(error, action: "Unexpected error. "))
        }
        
    }
    
    func showFailure(by error:Error) {
        self.showWarning(title: "Error", body: "Could not accept team invitation. \(error).", then: {
            self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
        })
    }
    
    func showSuccess() {
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
