//
//  TeamJoinCompleteController.swift
//  Krypton
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
    @IBOutlet weak var welcomeLabel:UILabel!

    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewUp:NSLayoutConstraint!
    @IBOutlet weak var resultViewDown:NSLayoutConstraint!


    var joinType:TeamJoinType!
    var teamIdentity:TeamIdentity!
    var createBlock:SigChain.SignedMessage!
    var teamName:String?
    
    struct JoinWorkflowError:Error, CustomDebugStringConvertible  {
        let error:Error
        let action:String
        
        init(_ error:Error, action:String) {
            self.error = error
            self.action = action
        }
        var debugDescription: String {
            return "\(action) Internal message: \(error)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        teamNameLabel.text = teamName
        
        resultViewUp.priority = UILayoutPriority(rawValue: 750)
        resultViewDown.priority = UILayoutPriority(rawValue: 999)
        self.view.layoutIfNeeded()
        
        switch joinType! {
        case .indirectInvite, .directInvite:
            joiningLabel.text = "JOINING"
            welcomeLabel.text = "Welcome to the team!"
        case .createFromApp:
            joiningLabel.text = "CREATING"
            welcomeLabel.text = "Your team is ready, and you're the first member. Welcome to the team!"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        
        self.finishJoinTeam()
    }
    
    func finishJoinTeam() {
        switch joinType! {
        case .directInvite:
            self.acceptDirectly()
            
        case .indirectInvite(let invite): // send team invite response
            self.accept(invite: invite)
            
        case .createFromApp(let settings):
            self.createTeam(with: settings)
        }
        
    }
    
    func createTeam(with settings:CreateFromAppSettings, onCompletion:((TeamIdentity) -> Void)? = nil) {
        self.createTeam() { identity in
            
            // for each setting add the block:
            dispatchAsync {
                do {
                    var newIdentity = identity
                    
                    // approve interval
                    let policy = SigChain.Policy(temporaryApprovalSeconds: SigChain.UTCTime(settings.autoApprovalInterval))
                    let (service, _) = try TeamService.shared().appendToMainChainSync(for: .setPolicy(policy))
                    newIdentity = service.teamIdentity
                    
                    if settings.auditLoggingEnabled {
                        let (service, _) = try service.appendToMainChainSync(for: .addLoggingEndpoint(.commandEncrypted))
                        newIdentity = service.teamIdentity
                    }
                    
                    for host in settings.hosts {
                        let (service, _) = try service.appendToMainChainSync(for: .pinHostKey(host))
                        newIdentity = service.teamIdentity
                    }
                    
                    do {
                        // save the team identity
                        try IdentityManager.setTeamIdentity(identity: service.teamIdentity)
                    } catch {
                        self.showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
                        return
                    }
                    
                    // subscribe to push
                    if let pushToken = UserDefaults.group?.string(forKey: Constants.pushTokenKey) {
                        do {
                            try service.subscribeToPushSync(with: pushToken)
                        }
                        catch {
                            log("team push subscription failed: \(error)", .error)
                        }
                    }

                    
                    onCompletion?(newIdentity)
                    self.showSuccess()

                    // partial error
                } catch {
                    self.showWarning(title: "Error", body: "Not all team settings were succesfully saved. Please check your team settings") {
                        self.showSuccess()
                    }
                }
            }
            
            
        }
    }
    
    // for .create
    func createTeam(onCompletion:((TeamIdentity) -> Void)? = nil) {
        
        do {
            
            let temporaryService = TeamService.temporary(for: teamIdentity)
            // create the team.
            try temporaryService.createTeam(signedMessage: createBlock) { response in
                switch response {
                case .error(let error):
                    self.showCreateFailure(message: "Could not create team", error: error)
                    
                case .result(let service):
                    self.teamIdentity = service.teamIdentity
                    
                    do {
                        // save the team identity
                        try IdentityManager.setTeamIdentity(identity: service.teamIdentity)
                    } catch {
                        self.showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
                        return
                    }
                    
                    onCompletion?(service.teamIdentity)
                }
            }
            
            
        } catch { // create errror
            self.showCreateFailure(message: "Error trying to create your team", error: error)
        }
    }
    
    
    
    // for invites
    func acceptDirectly() {
        dispatchAsync {
            do {
                let result = try TeamService.temporary(for: self.teamIdentity).acceptDirectInvitationSync()

                switch result {
                case .error(let error):
                    self.showFailure(by: JoinWorkflowError(error, action: "Team server error response on accept invite."))

                case .result(let service):
                    self.teamIdentity = service.teamIdentity
                    
                    // save the identity
                    do {
                        try IdentityManager.setTeamIdentity(identity: self.teamIdentity)
                    } catch {
                        self.showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
                        return
                    }
                    
                    self.showSuccess()
                }

            } catch {
                self.showFailure(by: JoinWorkflowError(error, action: "Unexpected error."))
            }
        }
    }

    func accept(invite:SigChain.IndirectInvitation.Secret, retry:Int = 3) {
        dispatchAsync {
            do {
                let result = try TeamService.temporary(for: self.teamIdentity).acceptSync(invite: invite)
                
                switch result {
                case .error(let error):
                    self.showFailure(by: JoinWorkflowError(error, action: "Team server error response on accept invite."))
                    
                case .result(let service):
                    self.teamIdentity = service.teamIdentity
                    
                    // save the identity
                    do {
                        try IdentityManager.setTeamIdentity(identity: self.teamIdentity)
                    } catch {
                        self.showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
                        return
                    }
                    
                    self.showSuccess()
                }
            } catch {
                self.showFailure(by: JoinWorkflowError(error, action: "Unexpected error."))
            }
        }
    }
    
    func showFailure(by error:JoinWorkflowError) {
        dispatchMain  {
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject
            
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
                
                if  case TeamService.ServerError.known(let knownError) = error.error,
                    case TeamService.ServerError.KnownServerErrorMessage.freeTierLimitReached = knownError
                {
                    self.showWarning(title: "Free Tier Limit Reached", body: "\(knownError.humanReadableError)", then: {
                        self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
                    })
                    return
                }
                
                self.showWarning(title: "Error", body: "Could not accept team invitation. \(error)", then: {
                    self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
                })
            }
        }
    }
    
    func showCreateFailure(message:String, error:Error) {
        dispatchMain  {
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject
            
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
                self.showWarning(title: "Error", body: "\(message). \(error).", then: {
                    self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
                })
            }
        }
    }

    
    func showSuccess() {
        dispatchMain {
            UIView.animate(withDuration: 0.3, animations: {
                
                switch self.joinType! {
                case .directInvite, .indirectInvite:
                    self.joiningLabel.text = "JOINED"
                case .createFromApp:
                    self.joiningLabel.text = "CREATED"
                }
                
                self.arcView.alpha = 0
                self.resultViewUp.priority = UILayoutPriority(rawValue: 999)
                self.resultViewDown.priority = UILayoutPriority(rawValue: 750)
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.toggleCheckState(true)
            }
        }
    }
    
    @IBAction func doneTapped() {
        self.performSegue(withIdentifier: "doneJoinTeam", sender: self)
    }
    
}
